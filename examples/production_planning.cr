# production_planning.cr
# This example models a classic production planning problem to maximize profit.
# A factory produces two types of goods (A and B) using limited resources: Labor and Raw Materials.
# It demonstrates variable creation, linear DSL expressions, constraint naming, and solver execution.
#
# Mathematical Formulation:
#   Maximize: 40.0 * Goods_A + 50.0 * Goods_B
#   Subject To:
#     2.0 * Goods_A <= 80.0 - 3.0 * Goods_B       (or: 2*Goods_A + 3*Goods_B <= 80)
#     4.0 * Goods_A <= 100.0 - 2.0 * Goods_B      (or: 4*Goods_A + 2*Goods_B <= 100)
#     Goods_A >= 0.5 * Goods_B                    (or: Goods_A - 0.5*Goods_B >= 0)
#     Goods_A >= 0.0, Goods_B >= 0.0

require "../src/optima"

# 1. Create a model with Maximize objective sense
model = Optima::Model.new("Factory Production Planning", Optima::ObjectiveSense::Maximize)

# 2. Define decision variables: quantity of Goods A and Goods B to produce.
# Both must be non-negative (lower_bound: 0.0).
goods_a = model.variable("Goods_A", lower_bound: 0.0)
goods_b = model.variable("Goods_B", lower_bound: 0.0)

# 3. Define the objective function: maximize total profit.
# Good A yields a profit of $40 per unit, Good B yields $50 per unit.
model.objective = 40.0 * goods_a + 50.0 * goods_b

# 4. Add resource constraints with terms on both the left-hand and right-hand sides
# Constraint 1: Labor limit. Goods A labor usage must not exceed remaining labor capacity after Goods B is produced.
model << {2.0 * goods_a <= 80.0 - 3.0 * goods_b, "Labor_Limit"}

# Constraint 2: Raw material limit. Goods A material usage must not exceed remaining material capacity after Goods B is produced.
model << {4.0 * goods_a <= 100.0 - 2.0 * goods_b, "Material_Limit"}

# Constraint 3: Production balance. Good A production must be at least half of Good B production.
model << {goods_a >= 0.5 * goods_b, "Production_Ratio"}

# 5. Initialize the solver (HighsSolver or fallback to CbcCliSolver if highs is not installed)
# We use CbcCliSolver here as it is highly portable via command line.
solver = Optima::CbcCliSolver.new
solver.time_limit = 10.0
solver.log_to_console = false

# 6. Solve the model
status = model.solve(solver)
puts "Solver Finished with Status: #{status}"

# 7. Output optimal solution
if status.optimal?
  puts "Optimal Profit: $#{solver.objective_value}"
  puts "Quantity of Goods A to produce: #{solver.value(goods_a)} units"
  puts "Quantity of Goods B to produce: #{solver.value(goods_b)} units"
end
