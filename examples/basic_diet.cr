# basic_diet.cr
# This is a basic introduction to Linear Programming (LP) using the classic Diet Problem.
# The goal is to select quantities of two foods (Oatmeal and Milk) to meet a minimum calorie requirement
# at the lowest cost.
# It uses only the most basic features: continuous variables, simple objective, and one inequality.
#
# Mathematical Formulation:
#   Minimize: 0.30 * Oatmeal + 0.25 * Milk
#   Subject To:
#     150.0 * Oatmeal + 100.0 * Milk >= 300.0
#     Oatmeal >= 0.0, Milk >= 0.0

require "../src/optima"

# 1. Create a model to minimize cost
model = Optima::Model.new("Basic Diet Problem", Optima::ObjectiveSense::Minimize)

# 2. Create decision variables representing servings of Oatmeal and Milk.
# Servings must be non-negative (lower_bound: 0.0).
oatmeal = model.variable("Oatmeal", lower_bound: 0.0)
milk = model.variable("Milk", lower_bound: 0.0)

# 3. Define the objective function: minimize total food cost.
# One serving of Oatmeal costs $0.30, one serving of Milk costs $0.25.
model.objective = 0.30 * oatmeal + 0.25 * milk

# 4. Add the calorie requirement constraint
# Oatmeal provides 150 calories per serving, Milk provides 100 calories per serving.
# We must consume at least 300 calories.
model << {150.0 * oatmeal + 100.0 * milk >= 300.0, "Calorie_Requirement"}

# 5. Initialize the solver (we use CbcCliSolver as it doesn't require compiling C libraries)
solver = Optima::CbcCliSolver.new
solver.log_to_console = false

# 6. Solve the model
status = model.solve(solver)
puts "Solver Finished with Status: #{status}"

# 7. Print the optimal diet plan
if status.optimal?
  puts "Optimal Daily Cost: $#{solver.objective_value.round(2)}"
  puts "Oatmeal servings: #{solver.value(oatmeal).round(2)}"
  puts "Milk servings: #{solver.value(milk).round(2)}"
end
