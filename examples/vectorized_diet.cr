# vectorized_diet.cr
# This example models a multi-nutrient Diet Problem using vectorized matrix modeling with `num.cr`.
# The goal is to minimize total food cost while satisfying daily intake requirements for multiple nutrients
# (Calories, Protein, Fat) across three foods (Oats, Milk, Eggs).
#
# Mathematical Formulation:
#   Minimize: 0.35 * x_0 + 0.25 * x_1 + 0.40 * x_2
#   Subject To:
#     150.0 * x_0 + 100.0 * x_1 + 70.0 * x_2 >= 300.0   (Calories limit)
#       6.0 * x_0 +   8.0 * x_1 +  6.0 * x_2 >= 20.0    (Protein limit)
#       2.0 * x_0 +   4.0 * x_1 +  5.0 * x_2 >= 10.0    (Fat limit)
#     x_i >= 0.0                                        forall i in {0, 1, 2}

require "num"
require "../src/optima"

# 1. Create a model to minimize cost
model = Optima::Model.new("Vectorized Diet Problem", Optima::ObjectiveSense::Minimize)

# 2. Create a variable vector of size 3 (number of foods)
# x[0] = servings of Oats, x[1] = servings of Milk, x[2] = servings of Eggs
x = model.variable_vector("food", size: 3)

# 3. Define the unit costs vector for foods (Oats: $0.35, Milk: $0.25, Eggs: $0.40)
costs = Tensor.from_array([0.35, 0.25, 0.40])

# Objective: Minimize cost (computed via manually summing the products of costs and variable elements)
model.objective = costs.to_unsafe[0] * x.to_unsafe[0] + costs.to_unsafe[1] * x.to_unsafe[1] + costs.to_unsafe[2] * x.to_unsafe[2]

# 4. Define the nutrient coefficient matrix A (shape 3x3)
# Row 0: Calories per serving (Oats: 150, Milk: 100, Eggs: 70)
# Row 1: Protein per serving in grams (Oats: 6g, Milk: 8g, Eggs: 6g)
# Row 2: Fat per serving in grams (Oats: 2g, Milk: 4g, Eggs: 5g)
nutrient_matrix = Tensor.from_array([
  [150.0, 100.0, 70.0],
  [6.0, 8.0, 6.0],
  [2.0, 4.0, 5.0],
])

# 5. Multiply matrix by variable vector to get nutrient expression vector of shape [3]
nutrient_intake = nutrient_matrix * x

# 6. Define the daily minimum nutrient requirements vector
# Calories >= 300, Protein >= 20g, Fat >= 10g
min_requirements = Tensor.from_array([300.0, 20.0, 10.0])

# 7. Create element-wise constraints (nutrient_intake >= min_requirements)
# We perform element-wise comparisons to construct the constraints tensor
constraints = nutrient_intake >= min_requirements

# 8. Append constraints vector to the model
model << constraints

# 9. Solve using CLI solver
solver = Optima::CbcCliSolver.new
solver.log_to_console = false

status = model.solve(solver)
puts "Status: #{status}"

if status.optimal?
  puts "Optimal Daily Cost: $#{solver.objective_value.round(2)}"
  puts "Oats servings: #{solver.value(x.to_unsafe[0]).round(2)}"
  puts "Milk servings: #{solver.value(x.to_unsafe[1]).round(2)}"
  puts "Eggs servings: #{solver.value(x.to_unsafe[2]).round(2)}"
end
