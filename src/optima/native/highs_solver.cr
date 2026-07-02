module Optima
  class HighsSolver < Solver
    property time_limit : Float64?
    property mip_gap : Float64?
    property log_to_console : Bool = false
    property path : String?
    property on_message : Proc(String, Void)?

    @highs : Void*
    @objective_value : Float64 = 0.0
    @solution : Hash(Int32, Float64)
    @reduced_costs : Hash(Int32, Float64)
    @shadow_prices : Hash(Int32, Float64)

    def initialize
      @highs = LibHighs.Highs_create
      @solution = {} of Int32 => Float64
      @reduced_costs = {} of Int32 => Float64
      @shadow_prices = {} of Int32 => Float64
    end

    def finalize
      if @highs
        LibHighs.Highs_destroy(@highs)
      end
    end

    def solve(model : Model) : SolverStatus
      if model.variables.empty?
        raise ModelError.new("Cannot solve a model with zero variables")
      end
      model.raise_on_quadratic_constraints!

      Optima::Log.info { "Solving optimization model '#{model.name}' with HiGHS..." }

      # 1. Clear/recreate solver instance to avoid state leakage in iterative solves
      if @highs
        LibHighs.Highs_destroy(@highs)
      end
      @highs = LibHighs.Highs_create
      @solution.clear
      @reduced_costs.clear
      @shadow_prices.clear

      # Apply options
      LibHighs.Highs_setBoolOptionValue(@highs, "output_flag", log_to_console ? 1 : 0)
      if limit = @time_limit
        LibHighs.Highs_setDoubleOptionValue(@highs, "time_limit", limit.to_f64)
      end
      if gap = @mip_gap
        LibHighs.Highs_setDoubleOptionValue(@highs, "mip_rel_gap", gap.to_f64)
      end

      if @on_message
        boxed = Box(HighsSolver).new(self)
        LibHighs.Highs_setCallback(@highs, ->HighsSolver.highs_callback(LibC::Int, LibC::Char*, Void*, Void*, Void*), boxed.as(Void*))
        LibHighs.Highs_startCallback(@highs, 0)
      end

      # 2. Set objective sense (Minimize = 1, Maximize = -1)
      LibHighs.Highs_changeObjectiveSense(@highs, model.sense.value)

      # 3. Add variables (columns)
      obj_expr = model.objective
      Optima::Log.debug { "Adding #{model.variables.size} variables..." }
      model.variables.each do |var|
        cost = obj_expr ? obj_expr.terms.fetch(var, 0.0) : 0.0
        status = LibHighs.Highs_addCol(
          @highs,
          cost.to_f64,
          var.lower_bound.to_f64,
          var.upper_bound.to_f64,
          0,
          nil,
          nil
        )
        if status != 0
          raise SolverError.new("Failed to add variable column '#{var.name}' to HiGHS")
        end

        # If it's mixed-integer/binary/semi, set column integrality
        if var.var_type.integer? || var.var_type.binary?
          # 1 = kHighsVarTypeInteger
          LibHighs.Highs_changeColIntegrality(@highs, var.id, 1)
        elsif var.var_type.semi_continuous?
          # 2 = kHighsVarTypeSemiContinuous
          LibHighs.Highs_changeColIntegrality(@highs, var.id, 2)
        elsif var.var_type.semi_integer?
          # 3 = kHighsVarTypeSemiInteger
          LibHighs.Highs_changeColIntegrality(@highs, var.id, 3)
        end
      end

      # 4. Add constraints (rows)
      model.constraints.each do |constraint|
        expr = constraint.expr
        num_nz = expr.terms.size

        indices = Array(LibHighs::HighsInt).new(num_nz)
        values = Array(LibC::Double).new(num_nz)

        expr.terms.each do |var, coeff|
          indices << var.id
          values << coeff.to_f64
        end

        # Normalize boundaries: LHS + constant op 0  =>  LHS op -constant
        rhs = -expr.constant

        lower = 0.0
        upper = 0.0

        if ru = constraint.range_upper
          lower = rhs
          upper = ru
        else
          case constraint.constraint_type
          when ConstraintType::LessThanOrEqual
            lower = -Float64::INFINITY
            upper = rhs
          when ConstraintType::GreaterThanOrEqual
            lower = rhs
            upper = Float64::INFINITY
          when ConstraintType::Equal
            lower = rhs
            upper = rhs
          end
        end

        status = LibHighs.Highs_addRow(
          @highs,
          lower,
          upper,
          num_nz,
          indices.to_unsafe,
          values.to_unsafe
        )

        if status != 0
          raise SolverError.new("Failed to add constraint row to HiGHS")
        end
      end

      # If Hessian is not empty, pass it to solver
      if !model.hessian.empty?
        dim = model.variables.size

        hessian_starts = Array(LibHighs::HighsInt).new(dim + 1, 0)
        hessian_index = Array(LibHighs::HighsInt).new
        hessian_value = Array(LibC::Double).new

        current_nz = 0
        (0...dim).each do |c|
          hessian_starts[c] = current_nz
          col_var = model.variables[c]
          (c...dim).each do |r|
            row_var = model.variables[r]
            val = model.hessian.fetch({col_var, row_var}, 0.0) + model.hessian.fetch({row_var, col_var}, 0.0)
            if r == c
              val = model.hessian.fetch({col_var, col_var}, 0.0)
            end

            if val != 0.0
              hessian_index << r
              hessian_value << val.to_f64
              current_nz += 1
            end
          end
        end
        hessian_starts[dim] = current_nz

        # Format 1 is kHighsHessianFormatTriangular (lower triangular)
        status = LibHighs.Highs_passHessian(
          @highs,
          dim,
          current_nz,
          1,
          hessian_starts.to_unsafe,
          hessian_index.to_unsafe,
          hessian_value.to_unsafe
        )
        if status != 0
          raise SolverError.new("Failed to pass Hessian matrix to HiGHS")
        end
      end

      # 5. Run the solver
      solve_status = LibHighs.Highs_run(@highs)
      if @on_message
        LibHighs.Highs_stopCallback(@highs, 0)
      end
      if solve_status != 0 && solve_status != 1 # 0 = Ok, 1 = Warning
        raise SolverError.new("HiGHS Solver run failed with status #{solve_status}")
      end

      # 6. Retrieve solution & duals
      num_vars = model.variables.size
      num_constraints = model.constraints.size

      col_values = Array(Float64).new(num_vars, 0.0)
      col_duals = Array(Float64).new(num_vars, 0.0)
      row_values = Array(Float64).new(num_constraints, 0.0)
      row_duals = Array(Float64).new(num_constraints, 0.0)

      LibHighs.Highs_getSolution(
        @highs,
        num_vars > 0 ? col_values.to_unsafe : Pointer(Float64).null,
        num_vars > 0 ? col_duals.to_unsafe : Pointer(Float64).null,
        num_constraints > 0 ? row_values.to_unsafe : Pointer(Float64).null,
        num_constraints > 0 ? row_duals.to_unsafe : Pointer(Float64).null
      )

      model.variables.each do |var|
        @solution[var.id] = col_values[var.id]
        @reduced_costs[var.id] = col_duals[var.id]
      end

      model.constraints.each do |constraint|
        if cid = constraint.id
          @shadow_prices[cid] = row_duals[cid]
        end
      end

      @objective_value = LibHighs.Highs_getObjectiveValue(@highs).to_f64

      # 7. Map model status
      model_status = LibHighs.Highs_getModelStatus(@highs)
      status = case model_status
               when 7 # kOptimal
                 SolverStatus::Optimal
               when 8 # kInfeasible
                 SolverStatus::Infeasible
               when 10 # kUnbounded
                 SolverStatus::Unbounded
               when 9 # kUnboundedOrInfeasible
                 SolverStatus::InfeasibleOrUnbounded
               else
                 SolverStatus::Unknown
               end

      Optima::Log.info { "Optimization completed. Status: #{status}, Objective: #{@objective_value}" }
      status
    end

    def value(variable : Variable) : Float64
      @solution.fetch(variable.id, 0.0)
    end

    def reduced_cost(variable : Variable) : Float64
      @reduced_costs.fetch(variable.id, 0.0)
    end

    def shadow_price(constraint : Constraint) : Float64
      if cid = constraint.id
        @shadow_prices.fetch(cid, 0.0)
      else
        0.0
      end
    end

    def objective_value : Float64
      @objective_value
    end

    def read_model(filename : String) : Bool
      LibHighs.Highs_readModel(@highs, filename.to_unsafe) == 0
    end

    def write_model(filename : String) : Bool
      LibHighs.Highs_writeModel(@highs, filename.to_unsafe) == 0
    end

    def set_solution(col_value : Array(Float64)) : Bool
      LibHighs.Highs_setSolution(
        @highs,
        col_value.to_unsafe,
        Pointer(Float64).null,
        Pointer(Float64).null,
        Pointer(Float64).null
      ) == 0
    end

    def simplex_iteration_count : Int32
      val = 0
      LibHighs.Highs_getIntInfoValue(@highs, "simplex_iteration_count", pointerof(val))
      val
    end

    def mip_node_count : Int64
      val = 0
      LibHighs.Highs_getIntInfoValue(@highs, "mip_node_count", pointerof(val))
      val.to_i64
    end

    def mip_dual_bound : Float64
      val = 0.0
      LibHighs.Highs_getDoubleInfoValue(@highs, "mip_dual_bound", pointerof(val))
      val
    end

    def active_variables(model : Model, epsilon : Float64 = 1e-9) : Hash(Variable, Float64)
      active = ({} of Variable => Float64).compare_by_identity
      model.variables.each do |var|
        val = value(var)
        if val.abs > epsilon
          active[var] = val
        end
      end
      active
    end

    protected def self.highs_callback(cb_type : LibC::Int, msg : LibC::Char*, out_data : Void*, in_data : Void*, user_data : Void*)
      solver = Box(HighsSolver).unbox(user_data)
      if cb = solver.on_message
        cb.call(String.new(msg))
      end
    end
  end
end
