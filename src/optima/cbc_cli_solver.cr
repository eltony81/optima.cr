require "json"
require "./solver"
require "./exceptions"

module Optima
  class CbcCliSolver < Solver
    property time_limit : Float64?
    property mip_gap : Float64?
    property log_to_console : Bool = false
    property path : String = "cbc"
    property on_message : Proc(String, Void)?

    @objective_value : Float64 = 0.0
    @solution : Hash(String, Float64)

    def initialize
      @solution = {} of String => Float64
    end

    def solve(model : Model) : SolverStatus
      if model.variables.empty?
        raise ModelError.new("Cannot solve a model with zero variables")
      end

      Optima::Log.info { "Solving optimization model '#{model.name}' with CBC CLI..." }

      @solution.clear
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
        args = [lp_path]
        if limit = @time_limit
          args << "sec" << limit.to_s
        end
        if gap = @mip_gap
          args << "ratio" << gap.to_s
        end
        args << "log" << (log_to_console ? "1" : "0")
        args << "solve" << "solution" << sol_path

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
          raise SolverError.new("Failed to execute cbc solver binary at '#{cmd_path}': #{ex.message}")
        ensure
          output_io.close unless output_io.closed?
          input_io.close unless input_io.closed?
        end

        if !File.exists?(sol_path)
          return SolverStatus::Infeasible
        end

        lines = File.read_lines(sol_path)
        if lines.empty?
          return SolverStatus::Unknown
        end

        first_line = lines[0]
        if first_line.includes?("Optimal")
          status = SolverStatus::Optimal
        elsif first_line.includes?("Infeasible")
          status = SolverStatus::Infeasible
        elsif first_line.includes?("Unbounded")
          status = SolverStatus::Unbounded
        elsif first_line.includes?("Stopped on time") || first_line.includes?("Stopped on user")
          status = SolverStatus::UserAborted
        else
          status = SolverStatus::Unknown
        end

        if match = first_line.match(/objective value\s+([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)/)
          @objective_value = match[1].to_f64
        end

        lines[1..].each do |line|
          parts = line.strip.split
          next if parts.size < 3
          var_name = parts[1]
          val = parts[2].to_f64? || 0.0
          @solution[var_name] = val
        end

        Optima::Log.info { "Optimization completed. Status: #{status}, Objective: #{@objective_value}" }
        status
      ensure
        File.delete(lp_path) if File.exists?(lp_path)
        File.delete(sol_path) if File.exists?(sol_path)
        # Attempt to delete the directory if it's empty
        begin
          Dir.delete(dir) if Dir.exists?(dir)
        rescue
          # Ignore if not empty
        end
      end
    end

    def value(variable : Variable) : Float64
      @solution.fetch(variable.name, 0.0)
    end

    def objective_value : Float64
      @objective_value
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
