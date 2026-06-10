# basic_milp.cr
# This is a basic introduction to Mixed-Integer Linear Programming (MILP) using the Knapsack Problem.
# A hiker is packing a backpack and must select a subset of items (Camera, Book, Tent)
# to maximize utility value without exceeding a maximum weight limit of 15 kg.
# It demonstrates binary variables (0 or 1 decision) and simple integer constraints.
#
# Mathematical Formulation:
#   Maximize: 8 * Pack_Camera + 3 * Pack_Book + 10 * Pack_Tent
#   Subject To:
#     2 * Pack_Camera + 1 * Pack_Book + 13 * Pack_Tent <= 15
#     Pack_Camera, Pack_Book, Pack_Tent in {0, 1}

require "../src/optima"

# 1. Create a model to maximize utility value
model = Optima::Model.new("Knapsack Backpack Problem", Optima::ObjectiveSense::Maximize)

# 2. Define binary decision variables (category: VariableType::Binary).
# 1 means item is packed, 0 means item is left behind.
camera = model.variable("Pack_Camera", category: Optima::VariableType::Binary)
book = model.variable("Pack_Book", category: Optima::VariableType::Binary)
tent = model.variable("Pack_Tent", category: Optima::VariableType::Binary)

# 3. Define the objective function: maximize total utility value.
# Camera utility = 8, Book utility = 3, Tent utility = 10.
model.objective = 8.0 * camera + 3.0 * book + 10.0 * tent

# 4. Add the backpack weight constraint
# Camera weighs 2 kg, Book weighs 1 kg, Tent weighs 13 kg. Total weight limit is 15 kg.
model << {2.0 * camera + 1.0 * book + 13.0 * tent <= 15.0, "Weight_Limit"}

# 5. Initialize the solver
solver = Optima::CbcCliSolver.new
solver.log_to_console = false

# 6. Solve the model
status = model.solve(solver)
puts "Solver Finished with Status: #{status}"

# 7. Print the packing list
if status.optimal?
  puts "Optimal Utility: #{solver.objective_value}"
  puts "Pack Camera? #{solver.value(camera) > 0.5 ? "Yes" : "No"}"
  puts "Pack Book?   #{solver.value(book) > 0.5 ? "Yes" : "No"}"
  puts "Pack Tent?   #{solver.value(tent) > 0.5 ? "Yes" : "No"}"
end
