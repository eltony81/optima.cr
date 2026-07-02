# Optima.cr

[![Latest Release](https://img.shields.io/github/v/release/eltony81/optima.cr)](https://github.com/eltony81/optima.cr/releases)
[![Crystal CI Status](https://github.com/eltony81/optima.cr/actions/workflows/ci.yml/badge.svg)](https://github.com/eltony81/optima.cr/actions/workflows/ci.yml)
[![Language: Crystal](https://img.shields.io/badge/Language-Crystal-blue.svg)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Optima.cr** is an algebraic modeling library written in Crystal for Linear Programming (LP) and Mixed-Integer Linear Programming (MILP). It provides a fluent, type-safe DSL using operator overloading (inspired by Python's PuLP) and binds natively to **HiGHS**, the state-of-the-art open-source C++ optimization solver.

---

## Key Features

*   **Fluent DSL**: Construct linear expressions, objectives, and constraints using natural mathematical operators (`+`, `-`, `*`, `<=`, `>=`, `==`).
*   **PuLP-like Helpers**: Use `lpSum` and `lpDot` for fast algebraic summation and vector dot products.
*   **Batch Variable Creation**: Create large dictionaries of variables mapped to index enumerables with `variable_dict`.
*   **MIP Option Control**: Fine-tune the solver using `time_limit`, `mip_gap`, and console log settings.
*   **Dual Value Support**: Easily extract reduced costs of variables and shadow prices of constraints.
*   **Quadratic Optimization (QP)**: Support quadratic objectives by passing symmetric Hessian matrices natively.
*   **Warm Starting**: Load starting solution vectors directly to accelerate solver convergence.
*   **Indicator Constraints**: Express conditional logic (if $z = 1 \implies Ax \le b$) with automated Big-M relaxation.
*   **Model File I/O**: Save or import problems directly in standardized `.lp` and `.mps` file formats.
*   **Safe Memory Lifecycle**: Automatic deallocation of C-pointers using Crystal's garbage collector finalization hooks.

---

## Prerequisites (C Libraries Installation)

To use `Optima.cr`, you must install the **HiGHS** library on your system so the compiler can link against it.

### Arch Linux / Manjaro
Install the development libraries via pacman:
```bash
sudo pacman -S highs
```

### macOS
Install via Homebrew:
```bash
brew install highs
```

### Ubuntu / Debian
Since older releases might lack precompiled packages, you can build from source or use apt if available:
```bash
sudo apt-get install libhighs-dev
```

### Building from Source (Fallback)
If packages are unavailable, build HiGHS from source:
```bash
git clone https://github.com/ERGO-Code/HiGHS.git
cd HiGHS
mkdir build
cd build
cmake ..
make
sudo make install
```

---

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  optima:
    github: eltony81/optima.cr
```

Then run:
```bash
shards install
```

---

## Usage Example

Below is a complete example showing how to build and solve a simple linear programming problem:

$$
\text{Maximize } z = 2x + 3y
$$
$$
\text{Subject to } x + y \le 10
$$
$$
x, y \ge 0
$$

```crystal
require "optima"

# 1. Create the model and specify optimization sense (:maximize or :minimize)
model = Optima::Model.new("Optimal Production", Optima::ObjectiveSense::Maximize)

# 2. Define decision variables with bounds and category (Continuous or Integer)
x = model.variable("x", lower_bound: 0.0)
y = model.variable("y", lower_bound: 0.0)

# 3. Define the objective function
model.objective = 2 * x + 3 * y

# 4. Add constraints to the model
model.add_constraint(x + y <= 10, name: "limit_resource")

# 5. Initialize the solver (HiGHS)
solver = Optima::HighsSolver.new

# 6. Solve the optimization model
status = model.solve(solver)

# 7. Print results
puts "Solver Status: #{status}"
if status.optimal?
  puts "Objective Value: #{solver.objective_value}"
  puts "Solved x: #{solver.value(x)}"
  puts "Solved y: #{solver.value(y)}"
end
```

---

## Advanced Features Reference

### 1. Batch Variables and Binary Types
Define multi-dimensional variables and binary models:
```crystal
routes = ["Milano", "Roma", "Napoli"]
# Creates variables named "x_Milano", "x_Roma", etc. auto-bounded between 0.0 and 1.0
x = model.variable_dict("x", routes, category: Optima::VariableType::Binary)
```

### 2. lpSum and lpDot
Use functional helpers to build large constraints inside loops:
```crystal
# Sums variables x["Milano"], x["Roma"], x["Napoli"] plus a constant
model.add_constraint(Optima.lpSum(x.values) <= 5.0)

# Multiplies coefficients [1.2, 2.5, 3.0] by variables [x["Milano"], x["Roma"], x["Napoli"]]
costs = [1.2, 2.5, 3.0]
model.add_constraint(Optima.lpDot(costs, x.values) <= 12.0)
```

### 3. Solver Parameter Configurations
Configure timeout limits, relative optimality gaps, or output logging:
```crystal
solver = Optima::HighsSolver.new
solver.time_limit = 60.0       # Halt solver after 60 seconds
solver.mip_gap = 0.01          # Stop once solver is within 1% of optimal bound
solver.log_to_console = true   # Stream solver log output to terminal
```

### 4. Shadow Prices & Reduced Costs
Examine sensitivity info directly from the solved system:
```crystal
status = model.solve(solver)
if status.optimal?
  # Access reduced cost of a variable
  puts "x[Roma] reduced cost: #{solver.reduced_cost(x["Roma"])}"

  # Access shadow price (dual value) of a constraint
  puts "Resource constraint shadow price: #{solver.shadow_price(limit_resource)}"
end
```

### 5. Model File I/O
Save the model currently loaded in the solver or import model files directly:
```crystal
# Write current model state to file
solver.write_model("model.lp")
solver.write_model("model.mps")

# Import an external model file
solver2 = Optima::HighsSolver.new
solver2.read_model("model.mps")
```

### 6. Warm Starting (MIP Start / Solution Guesses)
Provide initial solutions or optimal bases to speed up iterative optimizations:
```crystal
# Initial starting values for each decision variable column
initial_guesses = [1.0, 5.0, 0.0]
solver.set_solution(initial_guesses)
```

### 7. Indicator Constraints
Model logical implications such as "if binary variable $z = 1$, then $x + y \le 5$ must hold":
```crystal
# Define variables and base constraint
z = model.variable("z", category: Optima::VariableType::Binary)
c = x + y <= 5

# Express conditional implication: z == 1 => x + y <= 5 (using automated Big-M relaxation)
model.add_indicator_constraint(z, 1, c, big_m: 1000.0)
```

### 8. Quadratic Programming (QP) Hessian
Define quadratic objective functions of the form $\frac{1}{2}x^T Q x + c^T x$ by populating the Hessian relation matrix:
```crystal
# Minimize x^2 + 2y^2 - xy
# Populate symmetric Hessian terms (Q_xx = 2.0, Q_yy = 4.0, Q_xy = -1.0)
model.hessian[{x, x}] = 2.0
model.hessian[{y, y}] = 4.0
model.hessian[{x, y}] = -1.0
```

### 9. Range Constraints
Express range constraints using double-comparison syntax. The first comparison must be
parenthesized: Crystal desugars a bare `a <= b <= c` into `(a <= b) && (b <= c)`, which
would silently discard the lower bound since `<=` here returns a `Constraint`, not a `Bool`.
```crystal
# Define bounds mathematically in a single chained statement: 10 <= x + y <= 20
model << {(10 <= x + y) <= 20, "resource_range"}
```

### 10. Naming constraints with tuple appending
Append constraints and assign their identifiers in a single operation:
```crystal
model << {x + y <= 10, "resource_limit"}
```

### 11. Pure Crystal LP Exporter
Export the model directly into standard CPLEX LP file format text:
```crystal
# Generate standard LP file content string
lp_format_string = model.to_lp
File.write("problem.lp", lp_format_string)
```

### 12. Solver Progress Statistics
Retrieve simplex iterations, explored MIP branch nodes, and best dual bounds:
```crystal
status = model.solve(solver)
if status.optimal?
  puts "Simplex iterations: #{solver.simplex_iteration_count}"
  puts "MIP nodes explored: #{solver.mip_node_count}"
  puts "MIP best dual bound: #{solver.mip_dual_bound}"
end
```

### 13. Thread-Safe SolverPool
Manage multiple solvers safely across parallel fibers and threads:
```crystal
# Initialize a pool with a capacity of 4 HighsSolver instances
pool = Optima::SolverPool.new(capacity: 4)

# Safely checkout and use a solver in parallel fibers
spawn do
  pool.use do |solver|
    model.solve(solver)
  end
end
```

### 14. Structured Logging Integration
Track solving phases and progress using Crystal's native `Log` module:
```crystal
# Configure Optima's logger level
Optima::Log.level = Log::Severity::Debug
```

### 15. Safe Error Handling
Formulations or FFI errors raise descriptive exceptions rather than crashing or returning nil:
```crystal
begin
  model.solve(solver)
rescue ex : Optima::ModelError
  puts "Formulation error: #{ex.message}"
rescue ex : Optima::SolverError
  puts "Solver execution error: #{ex.message}"
end
```

### 16. JSON Serialization
Export optimization models directly to JSON strings:
```crystal
# Serialize model formulation
json_data = model.to_json

# Deserialize model formulation
deserialized_model = Optima::Model.from_json(json_data)
```

### 17. Sparsification
Clean up near-zero coefficient terms to reduce optimization complexity:
```crystal
# Removes terms with coefficient values smaller than epsilon (default 1e-9)
expression.sparsify!(epsilon: 1e-9)
```

### 18. Scaling Diagnostics
Analyze model scaling to prevent numerical solver errors:
```crystal
# Diagnose maximum/minimum coefficient values and ratio
min_c, max_c = model.diagnose_scaling
```

### 19. Semi-Continuous & Semi-Integer Variables
Define specialized categories supported natively by HiGHS:
```crystal
# Value must be 0.0 OR between 50.0 and 100.0
x = model.variable("turbine", category: Optima::VariableType::SemiContinuous, lower_bound: 50.0, upper_bound: 100.0)

# Value must be 0.0 OR integer between 10 and 50
y = model.variable("staff", category: Optima::VariableType::SemiInteger, lower_bound: 10.0, upper_bound: 50.0)
```

### 20. LP Format Parser
Parse CPLEX LP files back into Crystal algebraic objects:
```crystal
lp_text = "Maximize obj: 2 x Subject To c1: x <= 5 End"
model = Optima::Model.from_lp(lp_text)
```

### 21. Active Variables Filter
Filter outsolved variables with values above a given threshold:
```crystal
# Get solved variables with absolute value > 1e-9
non_zeros = solver.active_variables(model)
```

### 22. Automated Installation Diagnostics (Postinstall)
When the shard is installed, a diagnostic script runs automatically to check if the `highs` C library is available on the host system:
```bash
sh ext/compile_check.sh
```

### 23. Alternative Solver Backend (CbcCliSolver)
If you don't have the HiGHS C library installed, you can use the COIN-OR CBC command-line solver instead:
```crystal
# Initialize the CBC CLI solver
solver = Optima::CbcCliSolver.new
solver.path = "/usr/bin/cbc" # Default is "cbc"
solver.time_limit = 10.0
solver.mip_gap = 0.05
solver.log_to_console = false

# Solve using cbc via subprocess
status = model.solve(solver)
if status.optimal?
  puts "Objective: #{solver.objective_value}"
  puts "x: #{solver.value(x)}"
end
```

### 24. Quadratic Constraints DSL
Build complex quadratic constraints using intuitive algebraic multiplication operators:
```crystal
# Construct quadratic constraints: x * y <= 10
model << {x * y <= 10, "quadratic_limit"}

# Works with linear expression combinations: x * (y + 2) <= 15
model << {x * (y + 2) <= 15, "complex_limit"}
```

### 25. Weighted Multi-Objective Optimization
Configure multi-objective formulations with distinct weights:
```crystal
# Add objectives with separate weights
model.add_objective(2 * x + 3 * y, weight: 1.5)
model.add_objective(y - 5 * x, weight: 0.5)

# The model objective is automatically updated to the weighted sum:
# 1.5 * (2x + 3y) + 0.5 * (y - 5x) = 0.5x + 5.0y
```

### 26. Irreducible Infeasible Set (IIS) Finder
Identify the minimal set of conflicting constraints that cause model infeasibility:
```crystal
# Compute the minimal set of conflicting constraints
iis_constraints = model.compute_iis(solver)
puts "Conflict set size: #{iis_constraints.size}"
iis_constraints.each do |c|
  puts "Conflicting constraint: #{c.name}"
end
```

### 27. Numerical Sensitivity Analysis
Perform numerical perturbation analysis to evaluate objective coefficient and constraint boundary ranges:
```crystal
# Run sensitivity analysis with delta perturbation (default 1e-5)
report = model.sensitivity_analysis(solver, delta: 1e-5)

# Examine variable objective coefficient sensitivity
report.obj_coefficient_ranges.each do |var, (obj_minus, obj_plus)|
  puts "Var #{var.name} - Obj minus: #{obj_minus}, Obj plus: #{obj_plus}"
end

# Examine constraint RHS bounds sensitivity
report.rhs_ranges.each do |constraint, (obj_minus, obj_plus)|
  puts "Constraint #{constraint.name} - Obj minus: #{obj_minus}, Obj plus: #{obj_plus}"
end
```

### 28. Solver Callback Interface
Stream real-time solver log output and messages during solver runs using a clean callback interface:
```crystal
solver = Optima::HighsSolver.new
# Or: solver = Optima::CbcCliSolver.new
# Or: solver = Optima::GlpkCliSolver.new

solver.on_message = ->(msg : String) {
  puts "[Solver Log] #{msg.strip}"
}

model.solve(solver)
```

### 29. GLPK CLI Solver Backend
Use the GNU Linear Programming Kit (GLPK) `glpsol` executable as a backend solver:
```crystal
# Initialize GLPK CLI solver
solver = Optima::GlpkCliSolver.new
solver.path = "/usr/bin/glpsol" # Default is "glpsol"
solver.time_limit = 30
solver.log_to_console = true

# Solve using glpsol via subprocess
status = model.solve(solver)
```

### 30. Matrix/Vector Block Modeling (Vectorized DSL)
Build high-dimensional mathematical models efficiently using matrix-vector block arithmetic via the `num.cr` library:
```crystal
require "num"

# 1. Create a variable vector of size 3 (represented as a Tensor)
x = model.variable_vector("x", size: 3)

# 2. Define a coefficient matrix A (Tensor(Float64))
# A = [[2.0, 3.0, 1.0],
#      [1.0, 0.0, 5.0]]
coefs = Tensor.from_array([
  [2.0, 3.0, 1.0],
  [1.0, 0.0, 5.0]
])

# 3. Perform matrix-vector multiplication yielding an Expression Tensor
exprs = coefs * x

# 4. Define right-hand side vector (Tensor(Float64))
rhs = Tensor.from_array([10.0, 15.0])

# 5. Build element-wise constraint vector (Tensor(Constraint))
constraints = exprs <= rhs

# 6. Append constraints vector to the model in one go
model << constraints
```

---

## License

This shard is available as open source under the terms of the [MIT License](LICENSE).
