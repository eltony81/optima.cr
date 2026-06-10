# vectorized_blending.cr
# This example models a Blending Problem where we mix three raw materials (Oil, Gas, Coal)
# to produce a final energy fuel. We must satisfy quality requirements and budget limits.
# It showcases Matrix/Vector Block Modeling (Vectorized DSL) using the `num.cr` integration.
#
# Mathematical Formulation:
#   Minimize: 12.0 * x_0 + 8.0 * x_1 + 5.0 * x_2
#   Subject To:
#     10.0 * x_0 + 8.0 * x_1 + 6.0 * x_2 >= 150.0   (Energy output limit)
#     3.0 * x_0 + 2.0 * x_1 + 5.0 * x_2 <= 60.0     (Pollution cap limit)
#     x_i >= 0.0                                    forall i in {0, 1, 2}

require "num"
require "../src/optima"

# 1. Create a model
model = Optima::Model.new("Vectorized Blending", Optima::ObjectiveSense::Minimize)

# 2. Define decision variables: quantity of each ingredient (Oil, Gas, Coal) to use
# We create a 1D Tensor of variables of size 3.
x = model.variable_vector("ingredient", size: 3)

# 3. Define cost matrix (1D Float Tensor representing unit costs for Oil, Gas, Coal)
# Oil: $12/unit, Gas: $8/unit, Coal: $5/unit
costs = Tensor.from_array([12.0, 8.0, 5.0])

# Since both costs and x are 1D tensors, we compute the objective as their dot product.
# We can represent it as their element-wise product and then sum.
# Or we can construct it manually from the coefficients
model.objective = costs.to_unsafe[0] * x.to_unsafe[0] + costs.to_unsafe[1] * x.to_unsafe[1] + costs.to_unsafe[2] * x.to_unsafe[2]

# 4. Define quality attributes coefficient matrix A (2D Float Tensor of size 2x3)
# Row 1: Energy output per unit of raw material (Oil: 10, Gas: 8, Coal: 6)
# Row 2: Pollutant emissions per unit (Oil: 3, Gas: 2, Coal: 5)
a = Tensor.from_array([
  [10.0, 8.0, 6.0], # Energy coefficients
  [3.0, 2.0, 5.0],  # Pollutant coefficients
])

# 5. Perform matrix-vector multiplication yielding an Expression Tensor of shape [2]
# Row 1 expr: 10 * Oil + 8 * Gas + 6 * Coal
# Row 2 expr: 3 * Oil + 2 * Gas + 5 * Coal
exprs = a * x

# 6. Define right-hand side bounds (Tensor(Float64) of size 2)
# Limit 1: Energy output must be at least 150 units (using negative to represent >= if needed,
# or we can compare element-wise. For simplicity, we define RHS targets)
rhs = Tensor.from_array([150.0, 60.0])

# 7. Create element-wise constraints
# Constraint 1 (Energy output): exprs[0] >= 150.0
# Constraint 2 (Pollution cap): exprs[1] <= 60.0
# Since <= and >= can be created element-wise, we create them separately:
c_energy = exprs.to_unsafe[0] >= rhs.to_unsafe[0]
c_pollution = exprs.to_unsafe[1] <= rhs.to_unsafe[1]

# 8. Add constraints to model
model << c_energy
model << c_pollution

# 9. Solve using CLI solver (fallback solver)
solver = Optima::CbcCliSolver.new
solver.log_to_console = false

status = model.solve(solver)
puts "Status: #{status}"

if status.optimal?
  puts "Optimal Blending Cost: $#{solver.objective_value}"
  puts "Oil quantity to blend: #{solver.value(x.to_unsafe[0])} units"
  puts "Gas quantity to blend: #{solver.value(x.to_unsafe[1])} units"
  puts "Coal quantity to blend: #{solver.value(x.to_unsafe[2])} units"
end
