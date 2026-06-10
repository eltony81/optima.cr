module Optima
  class Model
    include JSON::Serializable

    property name : String
    property sense : ObjectiveSense
    property variables : Array(Variable)
    property constraints : Array(Constraint)
    property objective : Expression?
    property objectives : Array(Tuple(Expression, Float64))

    @[JSON::Field(ignore: true)]
    property hessian : Hash(Tuple(Variable, Variable), Float64)

    @[JSON::Field(ignore: true)]
    @variable_counter : Int32 = 0

    def initialize(@name : String, @sense : ObjectiveSense = ObjectiveSense::Minimize)
      @variables = [] of Variable
      @constraints = [] of Constraint
      @variable_counter = 0
      @hessian = {} of Tuple(Variable, Variable) => Float64
      @objectives = [] of Tuple(Expression, Float64)
    end

    def add_objective(expr : Expression, weight : Float64 = 1.0)
      @objectives << {expr, weight}
      sum = Expression.new
      @objectives.each do |e, w|
        sum += e * w
      end
      @objective = sum
    end

    def variable(name : String, lower_bound : Float64 = 0.0, upper_bound : Float64 = Float64::INFINITY, category : VariableType = VariableType::Continuous) : Variable
      if category.binary?
        lower_bound = 0.0
        upper_bound = 1.0
      end
      var = Variable.new(@variable_counter, name, category, lower_bound, upper_bound)
      @variable_counter += 1
      @variables << var
      var
    end

    def variable_dict(name : String, indices : Enumerable(T), lower_bound : Float64 = 0.0, upper_bound : Float64 = Float64::INFINITY, category : VariableType = VariableType::Continuous) : Hash(T, Variable) forall T
      dict = {} of T => Variable
      indices.each do |idx|
        dict[idx] = variable("#{name}_#{idx}", lower_bound, upper_bound, category)
      end
      dict
    end

    def variable_vector(name : String, size : Int32, category : VariableType = VariableType::Continuous, lower_bound : Float64 = 0.0, upper_bound : Float64 = Float64::INFINITY) : Tensor(Variable, CPU(Variable))
      Tensor(Variable, CPU(Variable)).new([size]) do |i|
        variable("#{name}_#{i}", category: category, lower_bound: lower_bound, upper_bound: upper_bound).as(Variable)
      end
    end

    def add_constraint(constraint : Constraint, name : String? = nil) : Constraint
      constraint.name = name if name
      add_constraint_internal(constraint)
      constraint
    end

    def <<(constraint : Constraint) : self
      add_constraint_internal(constraint)
      self
    end

    def <<(tuple : Tuple(Constraint, String)) : self
      constraint, name = tuple
      add_constraint(constraint, name)
      self
    end

    def <<(constraints : Tensor(Constraint, CPU(Constraint))) : self
      add_constraints(constraints)
      self
    end

    def add_constraints(constraints : Tensor(Constraint, CPU(Constraint)), names : Array(String)? = nil)
      constraints.each_with_index do |c, idx|
        name = names ? names[idx]? : nil
        add_constraint(c, name: name)
      end
    end

    private def add_constraint_internal(constraint : Constraint)
      constraint.id = @constraints.size
      @constraints << constraint
    end

    def objective=(expr : Variable)
      @objective = Expression.new(expr)
    end

    def objective=(expr : Expression)
      @objective = expr
    end

    def objective=(val : Number)
      @objective = Expression.new(val.to_f64)
    end

    def add_indicator_constraint(binary_var : Variable, binary_val : Int32, constraint : Constraint, big_m : Float64 = 1e6)
      expr = constraint.expr
      raise "binary_val must be 0 or 1" unless binary_val == 0 || binary_val == 1

      case constraint.constraint_type
      when ConstraintType::LessThanOrEqual
        new_expr = Expression.new(expr.terms, expr.constant)
        if binary_val == 1
          new_expr.terms[binary_var] = new_expr.terms.fetch(binary_var, 0.0) + big_m
          new_expr.constant -= big_m
        else
          new_expr.terms[binary_var] = new_expr.terms.fetch(binary_var, 0.0) - big_m
        end
        add_constraint(Constraint.new(new_expr, ConstraintType::LessThanOrEqual, constraint.name))
      when ConstraintType::GreaterThanOrEqual
        new_expr = Expression.new(expr.terms, expr.constant)
        if binary_val == 1
          new_expr.terms[binary_var] = new_expr.terms.fetch(binary_var, 0.0) - big_m
          new_expr.constant += big_m
        else
          new_expr.terms[binary_var] = new_expr.terms.fetch(binary_var, 0.0) + big_m
        end
        add_constraint(Constraint.new(new_expr, ConstraintType::GreaterThanOrEqual, constraint.name))
      when ConstraintType::Equal
        c1 = Constraint.new(expr, ConstraintType::LessThanOrEqual, constraint.name ? "#{constraint.name}_LE" : nil)
        c2 = Constraint.new(expr, ConstraintType::GreaterThanOrEqual, constraint.name ? "#{constraint.name}_GE" : nil)
        add_indicator_constraint(binary_var, binary_val, c1, big_m)
        add_indicator_constraint(binary_var, binary_val, c2, big_m)
      end
    end

    def to_lp : String
      String.build do |io|
        io << (sense.maximize? ? "Maximize\n" : "Minimize\n")
        if obj = objective
          io << " obj: "
          obj.terms.each_with_index do |(var, coeff), i|
            if i > 0 && coeff >= 0.0
              io << " + "
            elsif coeff < 0.0
              io << " - "
            end
            
            val = coeff.abs
            if val == 1.0
              io << var.name
            else
              io << val << " " << var.name
            end
          end
          if obj.constant != 0.0
            io << (obj.constant >= 0.0 ? " + " : " - ") << obj.constant.abs
          end
          io << "\n"
        else
          io << " obj: 0\n"
        end

        io << "Subject To\n"
        constraints.each_with_index do |c, idx|
          name = c.name || "c#{idx}"
          io << " " << name << ": "
          
          if ru = c.range_upper
            io << -c.expr.constant << " <= "
          end

          c.expr.terms.each_with_index do |(var, coeff), i|
            if i > 0 && coeff >= 0.0
              io << " + "
            elsif coeff < 0.0
              io << " - "
            end
            
            val = coeff.abs
            if val == 1.0
              io << var.name
            else
              io << val << " " << var.name
            end
          end

          if ru = c.range_upper
            io << " <= " << ru << "\n"
          else
            case c.constraint_type
            when ConstraintType::LessThanOrEqual
              io << " <= " << -c.expr.constant << "\n"
            when ConstraintType::GreaterThanOrEqual
              io << " >= " << -c.expr.constant << "\n"
            when ConstraintType::Equal
              io << " = " << -c.expr.constant << "\n"
            end
          end
        end

        io << "Bounds\n"
        variables.each do |v|
          io << " " << v.lower_bound << " <= " << v.name << " <= "
          if v.upper_bound == Float64::INFINITY
            io << "inf\n"
          else
            io << v.upper_bound << "\n"
          end
        end

        integers = variables.select { |v| v.var_type.integer? }
        if !integers.empty?
          io << "General\n"
          integers.each do |v|
            io << " " << v.name << "\n"
          end
        end

        binaries = variables.select { |v| v.var_type.binary? }
        if !binaries.empty?
          io << "Binary\n"
          binaries.each do |v|
            io << " " << v.name << "\n"
          end
        end

        io << "End\n"
      end
    end

    def diagnose_scaling : Tuple(Float64, Float64)
      min_coeff = Float64::MAX
      max_coeff = 0.0

      if obj = objective
        obj.terms.each_value do |coeff|
          abs_val = coeff.abs
          next if abs_val == 0.0
          min_coeff = abs_val if abs_val < min_coeff
          max_coeff = abs_val if abs_val > max_coeff
        end
      end

      constraints.each do |c|
        c.expr.terms.each_value do |coeff|
          abs_val = coeff.abs
          next if abs_val == 0.0
          min_coeff = abs_val if abs_val < min_coeff
          max_coeff = abs_val if abs_val > max_coeff
        end
      end

      if max_coeff > 0.0 && min_coeff < Float64::MAX
        ratio = max_coeff / min_coeff
        if ratio > 1e6
          Optima::Log.warn { "Numerical scaling warning: Max/Min coefficient ratio is #{ratio} (Max: #{max_coeff}, Min: #{min_coeff}). This can cause solver instability." }
        end
        {min_coeff, max_coeff}
      else
        {0.0, 0.0}
      end
    end

    def self.from_lp(lp_string : String) : Model
      model = Model.new("Parsed Model")
      section = :none
      var_map = {} of String => Variable
      
      lp_string.each_line do |line|
        line = line.strip.gsub(/\s+/, " ")
        next if line.empty? || line.starts_with?("\\")
        
        lower_line = line.downcase
        if lower_line.starts_with?("minimize")
          model.sense = ObjectiveSense::Minimize
          section = :objective
          next
        elsif lower_line.starts_with?("maximize")
          model.sense = ObjectiveSense::Maximize
          section = :objective
          next
        elsif lower_line.starts_with?("subject to") || lower_line.starts_with?("such that") || lower_line.starts_with?("s.t.")
          section = :constraints
          next
        elsif lower_line.starts_with?("bounds")
          section = :bounds
          next
        elsif lower_line.starts_with?("general") || lower_line.starts_with?("integer") || lower_line.starts_with?("generals")
          section = :general
          next
        elsif lower_line.starts_with?("binary") || lower_line.starts_with?("binaries")
          section = :binary
          next
        elsif lower_line.starts_with?("end")
          break
        end

        case section
        when :objective
          content = line.gsub(/^obj\s*:\s*/i, "")
          model.objective = parse_expression(content, model, var_map)
        when :constraints
          if line.includes?(":")
            parts = line.split(":", 2)
            name = parts[0].strip
            constraint_content = parts[1].strip
          else
            name = nil
            constraint_content = line
          end
          
          if constraint_content.includes?("<=") || constraint_content.includes?(">=") || constraint_content.includes?("=")
            op_indices = [] of {Int32, String}
            ["<=", ">=", "="].each do |op|
              idx = 0
              while (idx = constraint_content.index(op, idx))
                op_indices << {idx, op}
                idx += op.size
              end
            end
            op_indices.sort_by! { |x| x[0] }

            if op_indices.size == 2
              lower_val = constraint_content[0...op_indices[0][0]].strip.to_f64
              expr_text = constraint_content[op_indices[0][0] + op_indices[0][1].size...op_indices[1][0]].strip
              upper_val = constraint_content[op_indices[1][0] + op_indices[1][1].size..-1].strip.to_f64
              
              expr = parse_expression(expr_text, model, var_map)
              expr.constant -= lower_val
              c = Constraint.new(expr, ConstraintType::GreaterThanOrEqual, name)
              c.range_upper = upper_val
              model.add_constraint(c)
            elsif op_indices.size == 1
              op = op_indices[0][1]
              idx = op_indices[0][0]
              expr_text = constraint_content[0...idx].strip
              rhs_text = constraint_content[idx + op.size..-1].strip
              rhs = rhs_text.to_f64
              
              expr = parse_expression(expr_text, model, var_map)
              expr.constant -= rhs
              type = case op
                     when "<=" then ConstraintType::LessThanOrEqual
                     when ">=" then ConstraintType::GreaterThanOrEqual
                     else ConstraintType::Equal
                     end
              model.add_constraint(Constraint.new(expr, type, name))
            end
          end
        when :bounds
          if line.includes?("<=") && line.scan(/<=/).size == 2
            parts = line.split("<=")
            lower = parts[0].strip.to_f64
            var_name = parts[1].strip
            upper = parts[2].strip.to_f64
            
            var = var_map[var_name] ||= model.variable(var_name)
            var.lower_bound = lower
            var.upper_bound = upper
          elsif line.includes?("<=")
            parts = line.split("<=")
            var_name = parts[0].strip
            upper = parts[1].strip.to_f64
            var = var_map[var_name] ||= model.variable(var_name)
            var.upper_bound = upper
          elsif line.includes?(">=")
            parts = line.split(">=")
            var_name = parts[0].strip
            lower = parts[1].strip.to_f64
            var = var_map[var_name] ||= model.variable(var_name)
            var.lower_bound = lower
          end
        when :general
          var_name = line.strip
          if var = var_map[var_name]?
            var.var_type = VariableType::Integer
          end
        when :binary
          var_name = line.strip
          if var = var_map[var_name]?
            var.var_type = VariableType::Binary
            var.lower_bound = 0.0
            var.upper_bound = 1.0
          end
        end
      end
      model
    end

    private def self.parse_expression(text : String, model : Model, var_map : Hash(String, Variable)) : Expression
      expr = Expression.new
      tokens = text.split(" ")
      i = 0
      sign = 1.0
      while i < tokens.size
        tok = tokens[i].strip
        if tok == "+"
          sign = 1.0
          i += 1
          next
        elsif tok == "-"
          sign = -1.0
          i += 1
          next
        end

        if tok.to_f64?
          val = tok.to_f64 * sign
          if i + 1 < tokens.size && !["+", "-", "<=", ">=", "="].includes?(tokens[i + 1]) && !tokens[i+1].to_f64?
            var_name = tokens[i + 1].strip
            var = var_map[var_name] ||= model.variable(var_name)
            expr.terms[var] = expr.terms.fetch(var, 0.0) + val
            i += 2
          else
            expr.constant += val
            i += 1
          end
        else
          var_name = tok
          var = var_map[var_name] ||= model.variable(var_name)
          expr.terms[var] = expr.terms.fetch(var, 0.0) + 1.0 * sign
          i += 1
        end
        sign = 1.0
      end
      expr
    end

    # Computes the Irreducible Infeasible Set (IIS) of constraints using a deletion filter.
    # Returns the minimal array of constraints causing infeasibility.
    def compute_iis(solver : Solver) : Array(Constraint)
      original_constraints = @constraints.dup
      status = solver.solve(self)
      unless status.infeasible? || status.infeasible_or_unbounded?
        return [] of Constraint
      end

      iis = [] of Constraint
      active_set = original_constraints.dup

      original_constraints.each do |c|
        active_set.delete(c)
        @constraints = active_set.dup

        temp_status = solver.solve(self)

        if temp_status.optimal?
          active_set << c
          iis << c
        end
      end

      @constraints = original_constraints
      iis
    end

    # Performs numerical sensitivity/ranging analysis by perturbing objectives and bounds.
    # Returns a SensitivityReport.
    def sensitivity_analysis(solver : Solver, delta : Float64 = 1e-5) : SensitivityReport
      report = SensitivityReport.new
      
      base_status = solver.solve(self)
      unless base_status.optimal?
        raise ModelError.new("Sensitivity analysis requires an optimal base solution")
      end

      original_obj_coeff = Hash(Variable, Float64).new
      if obj = @objective
        obj.terms.each do |var, coeff|
          original_obj_coeff[var] = coeff
        end
      end

      original_constraint_constants = Hash(Constraint, Float64).new
      @constraints.each do |c|
        original_constraint_constants[c] = c.expr.constant
      end

      if obj = @objective
        obj.terms.each_key do |var|
          obj.terms[var] = original_obj_coeff[var] + delta
          solver.solve(self)
          obj_plus = solver.objective_value
          
          obj.terms[var] = original_obj_coeff[var] - delta
          solver.solve(self)
          obj_minus = solver.objective_value

          obj.terms[var] = original_obj_coeff[var]
          report.obj_coefficient_ranges[var] = {obj_minus, obj_plus}
        end
      end

      @constraints.each do |c|
        c.expr.constant = original_constraint_constants[c] - delta
        solver.solve(self)
        obj_plus = solver.objective_value

        c.expr.constant = original_constraint_constants[c] + delta
        solver.solve(self)
        obj_minus = solver.objective_value

        c.expr.constant = original_constraint_constants[c]
        report.rhs_ranges[c] = {obj_minus, obj_plus}
      end

      solver.solve(self)
      report
    end

    def solve(solver : Solver) : SolverStatus
      solver.solve(self)
    end
  end
end
