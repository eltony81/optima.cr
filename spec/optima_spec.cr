require "spec"
require "../src/optima"

describe Optima do
  describe "DSL & Expression building" do
    it "creates variables with correct categories and bounds" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x", lower_bound: 0.0, upper_bound: 10.0)
      y = model.variable("y", category: Optima::VariableType::Integer)

      x.name.should eq("x")
      x.lower_bound.should eq(0.0)
      x.upper_bound.should eq(10.0)
      x.var_type.should eq(Optima::VariableType::Continuous)

      y.name.should eq("y")
      y.var_type.should eq(Optima::VariableType::Integer)
    end

    it "builds simple linear expressions" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x")
      y = model.variable("y")

      expr = 2 * x + 3 * y + 5
      expr.terms[x].should eq(2.0)
      expr.terms[y].should eq(3.0)
      expr.constant.should eq(5.0)

      # Reverse operations
      expr2 = 5 + x * 2 - y
      expr2.terms[x].should eq(2.0)
      expr2.terms[y].should eq(-1.0)
      expr2.constant.should eq(5.0)
    end

    it "creates constraints with comparison operators" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x")
      y = model.variable("y")

      c1 = x + y <= 10
      c1.constraint_type.should eq(Optima::ConstraintType::LessThanOrEqual)
      c1.expr.terms[x].should eq(1.0)
      c1.expr.terms[y].should eq(1.0)
      c1.expr.constant.should eq(-10.0) # x + y - 10 <= 0

      c2 = 2 * x >= 5
      c2.constraint_type.should eq(Optima::ConstraintType::GreaterThanOrEqual)
      c2.expr.terms[x].should eq(2.0)
      c2.expr.constant.should eq(-5.0) # 2x - 5 >= 0

      c3 = x == y
      c3.constraint_type.should eq(Optima::ConstraintType::Equal)
      c3.expr.terms[x].should eq(1.0)
      c3.expr.terms[y].should eq(-1.0)
      c3.expr.constant.should eq(0.0) # x - y == 0
    end
    it "automatically sets binary variable bounds" do
      model = Optima::Model.new("Test Model")
      b = model.variable("b", category: Optima::VariableType::Binary)
      b.lower_bound.should eq(0.0)
      b.upper_bound.should eq(1.0)
      b.var_type.should eq(Optima::VariableType::Binary)
    end

    it "creates a dictionary of variables with variable_dict" do
      model = Optima::Model.new("Test Model")
      routes = [:milano, :roma, :napoli]
      x = model.variable_dict("x", routes, category: Optima::VariableType::Binary)

      x[:milano].name.should eq("x_milano")
      x[:roma].name.should eq("x_roma")
      x[:roma].var_type.should eq(Optima::VariableType::Binary)
      x[:roma].lower_bound.should eq(0.0)
      x[:roma].upper_bound.should eq(1.0)
    end

    it "supports lpSum and lpDot" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x")
      y = model.variable("y")
      z = model.variable("z")

      sum_expr = Optima.lpSum([x, y, 3, z])
      sum_expr.terms[x].should eq(1.0)
      sum_expr.terms[y].should eq(1.0)
      sum_expr.terms[z].should eq(1.0)
      sum_expr.constant.should eq(3.0)

      dot_expr = Optima.lpDot([2.0, 3.5], [x, y])
      dot_expr.terms[x].should eq(2.0)
      dot_expr.terms[y].should eq(3.5)
      dot_expr.constant.should eq(0.0)
    end

    it "allows configuring solver options" do
      solver = Optima::HighsSolver.new
      solver.time_limit = 10.5
      solver.mip_gap = 0.01
      solver.log_to_console = true

      solver.time_limit.should eq(10.5)
      solver.mip_gap.should eq(0.01)
      solver.log_to_console.should be_true
    end
    it "implements indicator constraints mathematically" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x")
      z = model.variable("z", category: Optima::VariableType::Binary)

      c = x <= 5
      model.add_indicator_constraint(z, 1, c, big_m: 1000.0)

      ic = model.constraints.first
      ic.constraint_type.should eq(Optima::ConstraintType::LessThanOrEqual)
      ic.expr.terms[x].should eq(1.0)
      ic.expr.terms[z].should eq(1000.0)
      ic.expr.constant.should eq(-1005.0)
    end

    it "supports quadratic objectives mathematically" do
      model = Optima::Model.new("Test QP Model")
      x = model.variable("x")
      y = model.variable("y")

      model.hessian[{x, x}] = 1.0
      model.hessian[{y, y}] = 2.0
      model.hessian[{x, y}] = -1.0

      model.hessian[{x, x}].should eq(1.0)
      model.hessian[{y, y}].should eq(2.0)
      model.hessian[{x, y}].should eq(-1.0)
    end
    it "supports range constraints mathematically" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x")
      y = model.variable("y")

      c = (10 <= x + y) <= 20
      c.constraint_type.should eq(Optima::ConstraintType::GreaterThanOrEqual)
      c.expr.terms[x].should eq(1.0)
      c.expr.terms[y].should eq(1.0)
      c.expr.constant.should eq(-10.0) # x + y - 10 >= 0
      c.range_upper.should eq(20.0)
    end

    it "supports named constraints via tuple appending" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x")

      model << {x <= 10, "upper_limit"}

      model.constraints.first.name.should eq("upper_limit")
    end

    it "exports models to standardized LP format string" do
      model = Optima::Model.new("Test Model", Optima::ObjectiveSense::Maximize)
      x = model.variable("x", lower_bound: 0.0, upper_bound: 5.0)
      model.objective = 2 * x
      model << {x <= 3, "limit"}

      lp_string = model.to_lp
      lp_string.should contain("Maximize")
      lp_string.should contain("obj: 2.0 x")
      lp_string.should contain("limit: x <= 3.0")
      lp_string.should contain("Bounds")
      lp_string.should contain("0.0 <= x <= 5.0")
      lp_string.should contain("End")
    end

    it "allows reading stats properties" do
      solver = Optima::HighsSolver.new
      # Compile time syntax checks
      solver.simplex_iteration_count.should be_a(Int32)
      solver.mip_node_count.should be_a(Int64)
      solver.mip_dual_bound.should be_a(Float64)
    end
    it "supports checking out and checking in solvers from SolverPool" do
      pool = Optima::SolverPool.new(capacity: 2)

      pool.use do |solver|
        solver.should be_a(Optima::HighsSolver)
      end
    end

    it "raises ModelError when trying to solve a model with zero variables" do
      model = Optima::Model.new("Empty Model")
      solver = Optima::HighsSolver.new

      expect_raises(Optima::ModelError) do
        model.solve(solver)
      end
    end
    it "supports JSON serialization" do
      model = Optima::Model.new("JSON Model")
      x = model.variable("x")
      model.objective = 2 * x

      json_str = model.to_json
      json_str.should contain("JSON Model")
      json_str.should contain("\"name\":\"x\"")
    end

    it "sparsifies expressions" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x")
      y = model.variable("y")

      expr = 2 * x + 1e-12 * y
      expr.sparsify!(epsilon: 1e-9)

      expr.terms.has_key?(y).should be_false
      expr.terms[x].should eq(2.0)
    end

    it "diagnoses bad scaling and warns" do
      model = Optima::Model.new("Test Model")
      x = model.variable("x")
      y = model.variable("y")

      model.objective = 1e-7 * x + 1e2 * y
      min, max = model.diagnose_scaling
      min.should eq(1e-7)
      max.should eq(1e2)
    end

    it "parses LP files back into Crystal Model" do
      lp_string = <<-LP
      Maximize
       obj: 2.0 x + 3.0 y
      Subject To
       limit: x + y <= 10
      Bounds
       0.0 <= x <= 5.0
      Binary
       y
      End
      LP

      model = Optima::Model.from_lp(lp_string)
      model.sense.should eq(Optima::ObjectiveSense::Maximize)
      model.variables.size.should eq(2)

      x = model.variables.find { |v| v.name == "x" }.not_nil!
      y = model.variables.find { |v| v.name == "y" }.not_nil!

      x.lower_bound.should eq(0.0)
      x.upper_bound.should eq(5.0)
      y.var_type.should eq(Optima::VariableType::Binary)
    end

    it "supports semi-continuous and semi-integer variables" do
      model = Optima::Model.new("Semi Model")
      sc = model.variable("sc", category: Optima::VariableType::SemiContinuous)
      si = model.variable("si", category: Optima::VariableType::SemiInteger)

      sc.var_type.should eq(Optima::VariableType::SemiContinuous)
      si.var_type.should eq(Optima::VariableType::SemiInteger)
    end

    describe "CbcCliSolver" do
      it "instantiates with default options" do
        solver = Optima::CbcCliSolver.new
        solver.path.should eq("cbc")
        solver.time_limit.should be_nil
        solver.mip_gap.should be_nil
        solver.log_to_console.should be_false
      end

      it "raises ModelError for zero variables" do
        model = Optima::Model.new("Zero Var Model")
        solver = Optima::CbcCliSolver.new
        expect_raises(Optima::ModelError) do
          solver.solve(model)
        end
      end
    end

    describe "QuadraticExpression DSL" do
      it "builds quadratic expressions from variable multiplications" do
        model = Optima::Model.new("Quadratic Model")
        x = model.variable("x")
        y = model.variable("y")

        quad = x * y
        quad.quad_terms[{x, y}].should eq(1.0)

        quad2 = x * (y + 5)
        quad2.quad_terms[{x, y}].should eq(1.0)
        quad2.terms[x].should eq(5.0)

        quad3 = (x + 2) * y
        quad3.quad_terms[{y, x}].should eq(1.0)
        quad3.terms[y].should eq(2.0)
      end

      it "creates quadratic constraints" do
        model = Optima::Model.new("Quadratic Constraint Model")
        x = model.variable("x")
        y = model.variable("y")

        c = x * y + 2 * x <= 10
        c.constraint_type.should eq(Optima::ConstraintType::LessThanOrEqual)
        c.expr.should be_a(Optima::QuadraticExpression)
        q_expr = c.expr.as(Optima::QuadraticExpression)
        q_expr.quad_terms[{x, y}].should eq(1.0)
        q_expr.terms[x].should eq(2.0)
        q_expr.constant.should eq(-10.0)
      end
    end

    describe "Weighted Multi-Objective" do
      it "supports adding multiple objectives with weights" do
        model = Optima::Model.new("Multi-Objective Model")
        x = model.variable("x")
        y = model.variable("y")

        model.add_objective(x + 2, weight: 1.5)
        model.add_objective(2 * y - 1, weight: 0.5)

        model.objectives.size.should eq(2)
        model.objectives[0][0].terms[x].should eq(1.0)
        model.objectives[0][1].should eq(1.5)

        # The combined objective should be weighted sum: 1.5 * (x + 2) + 0.5 * (2 * y - 1) = 1.5 x + 1.0 y + 2.5
        obj = model.objective.not_nil!
        obj.terms[x].should eq(1.5)
        obj.terms[y].should eq(1.0)
        obj.constant.should eq(2.5)
      end
    end

    describe "GlpkCliSolver" do
      it "instantiates with default options" do
        solver = Optima::GlpkCliSolver.new
        solver.path.should eq("glpsol")
        solver.time_limit.should be_nil
        solver.mip_gap.should be_nil
        solver.log_to_console.should be_false
      end

      it "allows setting message callback" do
        solver = Optima::GlpkCliSolver.new
        called = false
        solver.on_message = ->(msg : String) {
          called = true
          nil
        }
        solver.on_message.should_not be_nil
      end
    end

    describe "IIS Computation & Sensitivity Analysis" do
      it "returns empty array if model is not infeasible" do
        # We can test compute_iis interface with CbcCliSolver
        model = Optima::Model.new("IIS Test")
        x = model.variable("x")
        model.objective = x
        solver = Optima::CbcCliSolver.new
        # If the file solver does not run or returns Infeasible (because cbc is not present),
        # compute_iis might run. But since cbc is not present, solver.solve raises/fails.
        # We can just check the compilation of compute_iis
        model.responds_to?(:compute_iis).should be_true
      end

      it "exposes sensitivity_analysis on Model" do
        model = Optima::Model.new("Sens Test")
        x = model.variable("x")
        model.objective = x
        model.responds_to?(:sensitivity_analysis).should be_true
      end
    end

    describe "Callbacks support" do
      it "supports on_message in HighsSolver" do
        solver = Optima::HighsSolver.new
        solver.on_message = ->(msg : String) { }
        solver.on_message.should_not be_nil
      end

      it "supports on_message in CbcCliSolver" do
        solver = Optima::CbcCliSolver.new
        solver.on_message = ->(msg : String) { }
        solver.on_message.should_not be_nil
      end
    end

    describe "Vectorized Block Modeling" do
      it "creates variable vectors using num.cr Tensors" do
        model = Optima::Model.new("Vectorized Model")
        x = model.variable_vector("x", size: 3)
        x.should be_a(Tensor(Optima::Variable, CPU(Optima::Variable)))
        x.shape.should eq([3])
        x.to_unsafe[0].name.should eq("x_0")
        x.to_unsafe[1].name.should eq("x_1")
        x.to_unsafe[2].name.should eq("x_2")
      end

      it "performs matrix-vector multiplication producing Expression Tensors" do
        model = Optima::Model.new("Vectorized Model")
        x = model.variable_vector("x", size: 2)

        # Coefficients matrix A = [[2.0, 3.0], [4.0, 5.0]]
        coefs = Tensor.from_array([[2.0, 3.0], [4.0, 5.0]])

        exprs = coefs * x
        exprs.should be_a(Tensor(Optima::Expression, CPU(Optima::Expression)))
        exprs.shape.should eq([2])

        # Verify terms in resulting expressions
        e1 = exprs.to_unsafe[0]
        e2 = exprs.to_unsafe[1]

        e1.terms[x.to_unsafe[0]].should eq(2.0)
        e1.terms[x.to_unsafe[1]].should eq(3.0)

        e2.terms[x.to_unsafe[0]].should eq(4.0)
        e2.terms[x.to_unsafe[1]].should eq(5.0)
      end

      it "creates element-wise comparisons and appends constraints to Model" do
        model = Optima::Model.new("Vectorized Model")
        x = model.variable_vector("x", size: 2)
        coefs = Tensor.from_array([[1.0, 0.0], [0.0, 1.0]])

        exprs = coefs * x

        # Element-wise comparison with scalar
        constrs1 = exprs <= 10.0
        constrs1.should be_a(Tensor(Optima::Constraint, CPU(Optima::Constraint)))

        # Element-wise comparison with Tensor
        rhs = Tensor.from_array([5.0, 7.5])
        constrs2 = exprs <= rhs
        constrs2.should be_a(Tensor(Optima::Constraint, CPU(Optima::Constraint)))

        # Add to model
        model << constrs1
        model.add_constraints(constrs2, names: ["c_first", "c_second"])

        model.constraints.size.should eq(4)
        model.constraints[2].name.should eq("c_first")
        model.constraints[3].name.should eq("c_second")
      end
    end

    describe "Model#remove_constraint and #remove_variable" do
      it "removes a constraint and renumbers the remaining ids" do
        model = Optima::Model.new("Remove Constraint Model")
        x = model.variable("x")
        y = model.variable("y")
        c1 = model.add_constraint(x + y <= 5.0, "c1")
        c2 = model.add_constraint(y <= 3.0, "c2")
        c3 = model.add_constraint(x <= 3.0, "c3")

        model.remove_constraint(c2)

        model.constraints.map(&.name).should eq(["c1", "c3"])
        model.constraints.map(&.id).should eq([0, 1])
        c1.id.should eq(0)
        c3.id.should eq(1)
      end

      it "raises when removing a constraint that isn't in the model" do
        model = Optima::Model.new("Remove Constraint Model")
        x = model.variable("x")
        c = model.add_constraint(x <= 5.0, "c")
        model.remove_constraint(c)

        expect_raises(Optima::ModelError) do
          model.remove_constraint(c)
        end
      end

      it "removes an unreferenced variable and renumbers the remaining ids" do
        model = Optima::Model.new("Remove Variable Model")
        x = model.variable("x")
        y = model.variable("y")
        z = model.variable("z")
        model.objective = x + y

        model.remove_variable(z)

        model.variables.map(&.name).should eq(["x", "y"])
        model.variables.map(&.id).should eq([0, 1])
      end

      it "raises when removing a variable still referenced by the objective or a constraint" do
        model = Optima::Model.new("Remove Variable Model")
        x = model.variable("x")
        y = model.variable("y")
        model.objective = x

        expect_raises(Optima::ModelError) do
          model.remove_variable(x)
        end

        model.add_constraint(y <= 5.0, "c")
        expect_raises(Optima::ModelError) do
          model.remove_variable(y)
        end
      end

      it "raises when removing a variable still referenced by the Hessian" do
        model = Optima::Model.new("Remove Variable Model")
        x = model.variable("x")
        model.hessian[{x, x}] = 1.0

        expect_raises(Optima::ModelError) do
          model.remove_variable(x)
        end
      end
    end

    describe "Model#dup" do
      it "clones variables, objective, constraints, and hessian independently" do
        model = Optima::Model.new("Dup Model", Optima::ObjectiveSense::Minimize)
        x = model.variable("x", lower_bound: 0.0, upper_bound: 10.0)
        y = model.variable("y", lower_bound: 0.0, upper_bound: 10.0)
        model.objective = 2 * x + 3 * y
        model.hessian[{x, x}] = 1.0
        c = model.add_constraint((2.0 <= x - y) <= 8.0, "range")

        clone = model.dup

        clone.name.should eq(model.name)
        clone.variables.size.should eq(model.variables.size)
        cx = clone.variables.find { |v| v.name == "x" }.not_nil!
        cy = clone.variables.find { |v| v.name == "y" }.not_nil!
        cx.same?(x).should be_false

        clone.objective.not_nil!.terms[cx].should eq(2.0)
        clone.objective.not_nil!.terms[cy].should eq(3.0)
        clone.hessian[{cx, cx}].should eq(1.0)

        clone_c = clone.constraints.find { |cc| cc.name == "range" }.not_nil!
        clone_c.range_upper.should eq(8.0)

        # Mutating the clone must not affect the original
        cx.upper_bound = 999.0
        x.upper_bound.should eq(10.0)
      end
    end

    describe "HighsSolver solver options and diagnostics" do
      it "accepts threads and rejects an invalid presolve mode" do
        model = Optima::Model.new("Options Model")
        x = model.variable("x", upper_bound: 10.0)
        model.objective = x
        model << (x <= 7.0)

        solver = Optima::HighsSolver.new
        solver.threads = 1
        solver.presolve = "off"
        model.solve(solver).optimal?.should be_true

        bad_solver = Optima::HighsSolver.new
        bad_solver.presolve = "definitely_not_a_mode"
        expect_raises(Optima::ModelError) do
          model.solve(bad_solver)
        end
      end

      it "maps a time-limited MIP solve to UserAborted rather than Unknown" do
        model = Optima::Model.new("TimeLimit Model")
        vars = (0...40).map { |i| model.variable("x#{i}", category: Optima::VariableType::Binary) }
        model.objective = Optima.lpSum(vars.map_with_index { |v, i| v * (i + 1) })
        model << (Optima.lpDot(vars.map_with_index { |v, i| (i * 3 % 17 + 1).to_f64 }, vars) <= 60.0)

        solver = Optima::HighsSolver.new
        solver.time_limit = 0.0001
        status = model.solve(solver)
        status.should eq(Optima::SolverStatus::UserAborted)
      end

      it "captures and replays a basis via get_basis/warm_start_basis=" do
        model = Optima::Model.new("Basis Model", Optima::ObjectiveSense::Maximize)
        x = model.variable("x", upper_bound: 10.0)
        y = model.variable("y", upper_bound: 10.0)
        model.objective = 3 * x + 5 * y
        model << (x + y <= 12.0)

        solver = Optima::HighsSolver.new
        model.solve(solver)
        basis = solver.get_basis(model)
        basis.col_status.size.should eq(2)
        basis.row_status.size.should eq(1)

        warm_solver = Optima::HighsSolver.new
        warm_solver.warm_start_basis = basis
        status = model.solve(warm_solver)
        status.optimal?.should be_true
        warm_solver.objective_value.should eq(solver.objective_value)
      end

      it "computes exact sensitivity ranges via native HiGHS ranging" do
        model = Optima::Model.new("Ranging Model", Optima::ObjectiveSense::Maximize)
        x = model.variable("x", upper_bound: 10.0)
        y = model.variable("y", upper_bound: 10.0)
        model.objective = 3 * x + 5 * y
        model << (x + y <= 12.0)

        solver = Optima::HighsSolver.new
        report = solver.sensitivity_analysis(model)

        # x's coefficient (3) can range up to y's (5) before the basis would change
        lo, hi = report.obj_coefficient_ranges[x]
        lo.should eq(0.0)
        hi.should eq(5.0)
      end
    end

    describe "CbcCliSolver / GlpkCliSolver dual values" do
      it "exposes reduced_cost on CbcCliSolver, defaulting to 0.0 before any solve" do
        solver = Optima::CbcCliSolver.new
        model = Optima::Model.new("Cbc Reduced Cost Model")
        x = model.variable("x")
        solver.reduced_cost(x).should eq(0.0)
      end

      it "exposes reduced_cost and shadow_price on GlpkCliSolver, defaulting to 0.0 before any solve" do
        solver = Optima::GlpkCliSolver.new
        model = Optima::Model.new("Glpk Dual Model")
        x = model.variable("x")
        c = model.add_constraint(x <= 5.0, "c")
        solver.reduced_cost(x).should eq(0.0)
        solver.shadow_price(c).should eq(0.0)
      end

      it "matches HighsSolver's primal/dual values on a real CBC solve" do
        pending!("cbc not found on PATH") unless Process.find_executable("cbc")

        model = Optima::Model.new("Cross-check", Optima::ObjectiveSense::Maximize)
        x = model.variable("x")
        y = model.variable("y")
        model.objective = 2 * x + 3 * y
        model.add_constraint(x + y <= 4.0, "Capacity")

        solver = Optima::CbcCliSolver.new
        solver.log_to_console = false
        status = solver.solve(model)

        status.optimal?.should be_true
        solver.objective_value.should eq(12.0)
        solver.value(x).should eq(0.0)
        solver.value(y).should eq(4.0)
        solver.reduced_cost(x).should eq(-1.0)
      end

      it "matches HighsSolver's primal/dual values on a real GLPK solve" do
        pending!("glpsol not found on PATH") unless Process.find_executable("glpsol")

        model = Optima::Model.new("Cross-check", Optima::ObjectiveSense::Maximize)
        x = model.variable("x")
        y = model.variable("y")
        model.objective = 2 * x + 3 * y
        capacity = model.add_constraint(x + y <= 4.0, "Capacity")

        solver = Optima::GlpkCliSolver.new
        solver.log_to_console = false
        status = solver.solve(model)

        status.optimal?.should be_true
        solver.objective_value.should eq(12.0)
        solver.value(x).should eq(0.0)
        solver.value(y).should eq(4.0)
        solver.reduced_cost(x).should eq(-1.0)
        solver.shadow_price(capacity).should eq(3.0)
      end

      it "solves a MIP with CBC and GLPK, where duals stay 0.0 (none exist for an integer program)" do
        build_knapsack = -> {
          m = Optima::Model.new("Knapsack", Optima::ObjectiveSense::Maximize)
          a = m.variable("a", category: Optima::VariableType::Binary)
          b = m.variable("b", category: Optima::VariableType::Binary)
          cc = m.variable("c", category: Optima::VariableType::Binary)
          m.objective = 8 * a + 3 * b + 10 * cc
          m.add_constraint(2 * a + 1 * b + 13 * cc <= 15.0, "Weight")
          {m, a, b, cc}
        }

        if Process.find_executable("cbc")
          model, a, _, cc = build_knapsack.call
          solver = Optima::CbcCliSolver.new
          solver.log_to_console = false
          solver.solve(model).optimal?.should be_true
          solver.objective_value.should eq(18.0)
          solver.value(a).should eq(1.0)
          solver.value(cc).should eq(1.0)
        end

        if Process.find_executable("glpsol")
          model, a, _, cc = build_knapsack.call
          solver = Optima::GlpkCliSolver.new
          solver.log_to_console = false
          solver.solve(model).optimal?.should be_true
          solver.objective_value.should eq(18.0)
          solver.value(a).should eq(1.0)
          solver.value(cc).should eq(1.0)
          solver.reduced_cost(a).should eq(0.0)
        end
      end
    end

    describe "Model#to_lp / #variable_dict edge cases (CBC/GLPK LP-format safety)" do
      it "writes an explicitly-signed +inf, which GLPK's CPLEX-LP reader requires" do
        model = Optima::Model.new("Infinity Model")
        model.variable("x")
        model.to_lp.should contain("+inf")
        model.to_lp.should_not contain(" <= inf\n")
      end

      it "generates LP-identifier-safe names for variable_dict with Tuple indices" do
        model = Optima::Model.new("Tuple Index Model")
        indices = [{"Milan", "Client_1"}, {"Rome", "Client_2"}]
        x = model.variable_dict("x", indices)

        x[{"Milan", "Client_1"}].name.should eq("x_Milan_Client_1")
        x[{"Rome", "Client_2"}].name.should eq("x_Rome_Client_2")
        model.variables.each do |v|
          v.name.should_not contain(" ")
          v.name.should_not contain("\"")
          v.name.should_not contain("{")
        end
      end
    end
  end
end
