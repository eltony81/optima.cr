require "json"
require "./solver"
require "./exceptions"

module Optima
  class GlpkCliSolver < Solver
    property time_limit : Float64?
    property mip_gap : Float64?
    property log_to_console : Bool = false
    property path : String = "glpsol"
    property on_message : Proc(String, Void)?

    @objective_value : Float64 = 0.0
    @solution : Hash(String, Float64)
    @reduced_costs : Hash(String, Float64)
    @shadow_prices : Hash(Int32, Float64)

    def initialize
      @solution = {} of String => Float64
      @reduced_costs = {} of String => Float64
      @shadow_prices = {} of Int32 => Float64
    end

    def solve(model : Model) : SolverStatus
      if model.variables.empty?
        raise ModelError.new("Cannot solve a model with zero variables")
      end

      Optima::Log.info { "Solving optimization model '#{model.name}' with GLPK CLI..." }

      @solution.clear
      @reduced_costs.clear
      @shadow_prices.clear
      @objective_value = 0.0

      dir = File.join(Dir.current, ".optima_tmp")
      Dir.mkdir_p(dir)
      id = Random::Secure.hex(8)
      lp_path = File.join(dir, "model_#{id}.lp")
      sol_path = File.join(dir, "model_#{id}.sol")

      begin
        # Write the LP file
        File.write(lp_path, model.to_lp)

        # Build command-line arguments
        # glpsol --lp <temp_lp> -w <temp_sol>
        args = ["--lp", lp_path, "-w", sol_path]
        if limit = @time_limit
          args << "--tmlim" << limit.to_i.to_s
        end
        if gap = @mip_gap
          args << "--mipgap" << gap.to_s
        end

        cmd_path = @path
        status = SolverStatus::Unknown

        output_io, input_io = IO.pipe
        begin
          process = Process.new(
            cmd_path,
            args,
            output: input_io,
            error: input_io
          )

          input_io.close

          output_io.each_line do |line|
            if log_to_console
              puts line
            end
            if cb = @on_message
              cb.call(line)
            end
          end

          process_status = process.wait
        rescue ex
          raise SolverError.new("Failed to execute glpsol solver binary at '#{cmd_path}': #{ex.message}")
        ensure
          output_io.close unless output_io.closed?
          input_io.close unless input_io.closed?
        end

        if !File.exists?(sol_path)
          return SolverStatus::Infeasible
        end

        # Parse GLPK solution file
        lines = File.read_lines(sol_path).reject { |l| l.strip.empty? || l.strip.starts_with?("#") }
        if lines.empty?
          return SolverStatus::Unknown
        end

        # Line 0: num_rows num_cols
        first_parts = lines[0].strip.split
        num_rows = first_parts[0].to_i
        num_cols = first_parts[1].to_i

        # Line 1: obj_sense obj_status obj_value
        second_parts = lines[1].strip.split
        obj_status = second_parts[1].to_i
        @objective_value = second_parts[2].to_f64

        status = case obj_status
                 when 5
                   SolverStatus::Optimal
                 when 3, 4
                   SolverStatus::Infeasible
                 when 6
                   SolverStatus::Unbounded
                 else
                   SolverStatus::Unknown
                 end

        row_offset = 2
        col_offset = 2 + num_rows

        # Row/col lines are "<stat> <prim> <dual>" for LP problems; MIP solutions omit
        # the trailing dual column entirely, so shadow_price/reduced_cost stay 0.0 for
        # those (there is no meaningful dual value to report for an integer program).
        model.constraints.each_with_index do |c, idx|
          line_idx = row_offset + idx
          next unless line_idx < lines.size
          parts = lines[line_idx].strip.split
          next unless parts.size >= 3 && (cid = c.id)
          @shadow_prices[cid] = parts[2].to_f64? || 0.0
        end

        model.variables.each_with_index do |var, idx|
          line_idx = col_offset + idx
          if line_idx < lines.size
            parts = lines[line_idx].strip.split
            val = parts[1].to_f64? || 0.0
            @solution[var.name] = val
            if parts.size >= 3
              @reduced_costs[var.name] = parts[2].to_f64? || 0.0
            end
          end
        end

        Optima::Log.info { "Optimization completed. Status: #{status}, Objective: #{@objective_value}" }
        status
      ensure
        File.delete(lp_path) if File.exists?(lp_path)
        File.delete(sol_path) if File.exists?(sol_path)
        begin
          Dir.delete(dir) if Dir.exists?(dir)
        rescue
        end
      end
    end

    def value(variable : Variable) : Float64
      @solution.fetch(variable.name, 0.0)
    end

    def objective_value : Float64
      @objective_value
    end

    # The 3rd ("dual") column from GLPK's plain column output. 0.0 for MIP solutions,
    # which have no meaningful reduced cost.
    def reduced_cost(variable : Variable) : Float64
      @reduced_costs.fetch(variable.name, 0.0)
    end

    # The 3rd ("dual") column from GLPK's plain row output. 0.0 for MIP solutions.
    def shadow_price(constraint : Constraint) : Float64
      if cid = constraint.id
        @shadow_prices.fetch(cid, 0.0)
      else
        0.0
      end
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
  end
end
