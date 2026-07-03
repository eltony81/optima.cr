# model_editing.cr
# Demonstrates editing a Model after it has been built: removing constraints/variables,
# and cloning a model to explore scenario variants without rebuilding it from scratch.
#
# Base problem - a small facility staffing LP:
#   Minimize: 20 * Morning + 25 * Evening + 30 * Night
#   Subject To:
#     Morning + Evening + Night >= 10   (minimum total staff)
#     Night <= 4                        (night shift headcount cap)

require "../src/optima"

model = Optima::Model.new("Staffing", Optima::ObjectiveSense::Minimize)
morning = model.variable("Morning", lower_bound: 0.0)
evening = model.variable("Evening", lower_bound: 0.0)
night = model.variable("Night", lower_bound: 0.0)
model.objective = 20 * morning + 25 * evening + 30 * night

staffing = model.add_constraint(morning + evening + night >= 10.0, "MinStaff")
night_cap = model.add_constraint(night <= 4.0, "NightCap")

solver = Optima::HighsSolver.new
status = model.solve(solver)
puts "Base plan: #{status}, cost = #{solver.objective_value}"

# 1. Model#remove_constraint: lift the night shift cap and re-solve.
# Removing renumbers the remaining constraints' ids so they still match their
# position in Model#constraints (solvers key duals/rows by that id).
model.remove_constraint(night_cap)
status = model.solve(solver)
puts "Without the night cap: #{status}, cost = #{solver.objective_value}"

# 2. Model#remove_variable: drop a shift from consideration entirely.
# This raises ModelError if the variable is still referenced anywhere (objective, a
# constraint, or the Hessian) - remove_variable itself won't guess how to patch up
# those references, so remove/rebuild them first, as done here for both the objective
# and the staffing constraint before removing `evening`.
model.objective = 20 * morning + 30 * night
model.remove_constraint(staffing)
model.add_constraint(morning + night >= 10.0, "MinStaff")
model.remove_variable(evening)
puts "Variables after removing Evening: #{model.variables.map(&.name)}"

status = model.solve(solver)
puts "Morning/Night only: #{status}, cost = #{solver.objective_value}"

# 3. Model#dup: explore a "what if wages rise" scenario without touching the original.
# The clone gets entirely fresh Variable instances, so mutating one model's bounds
# or re-solving it never affects the other.
raise_scenario = model.dup
raise_morning = raise_scenario.variables.find { |v| v.name == "Morning" }.not_nil!
raise_night = raise_scenario.variables.find { |v| v.name == "Night" }.not_nil!
raise_scenario.objective = 24 * raise_morning + 30 * raise_night

scenario_solver = Optima::HighsSolver.new
raise_scenario.solve(scenario_solver)
puts "Original cost:        #{solver.objective_value}"
puts "Wage-raise scenario:   #{scenario_solver.objective_value}"
puts "Original still solves the same way: #{model.solve(solver)}, cost = #{solver.objective_value}"
