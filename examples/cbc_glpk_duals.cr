# cbc_glpk_duals.cr
# Demonstrates reduced costs (CbcCliSolver, GlpkCliSolver) and shadow prices
# (GlpkCliSolver only) - dual values read from the extra column CBC/GLPK already
# write into their solution files, alongside the primal values Optima.cr already
# parsed. Requires the `cbc` and `glpsol` binaries on PATH (see README.md).
#
# Mathematical Formulation:
#   Maximize: 2 * x + 3 * y
#   Subject To:
#     x + y <= 4
#     x, y >= 0

require "../src/optima"

model = Optima::Model.new("Dual Values Demo", Optima::ObjectiveSense::Maximize)
x = model.variable("x")
y = model.variable("y")
model.objective = 2 * x + 3 * y
capacity = model.add_constraint(x + y <= 4.0, "Capacity")

puts "--- CbcCliSolver ---"
cbc_solver = Optima::CbcCliSolver.new
cbc_solver.log_to_console = false
status = model.solve(cbc_solver)
puts "Status: #{status}"
if status.optimal?
  puts "x = #{cbc_solver.value(x)}, reduced cost = #{cbc_solver.reduced_cost(x)}"
  puts "y = #{cbc_solver.value(y)}, reduced cost = #{cbc_solver.reduced_cost(y)}"
  # CBC's plain solution file has no row-level dual values, so CbcCliSolver has no
  # shadow_price - only HighsSolver and GlpkCliSolver expose constraint duals.
end

puts "--- GlpkCliSolver ---"
glpk_solver = Optima::GlpkCliSolver.new
glpk_solver.log_to_console = false
status = model.solve(glpk_solver)
puts "Status: #{status}"
if status.optimal?
  puts "x = #{glpk_solver.value(x)}, reduced cost = #{glpk_solver.reduced_cost(x)}"
  puts "y = #{glpk_solver.value(y)}, reduced cost = #{glpk_solver.reduced_cost(y)}"
  puts "Capacity shadow price = #{glpk_solver.shadow_price(capacity)}"
end
