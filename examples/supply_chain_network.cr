# supply_chain_network.cr
# This example models a supply chain network optimization problem.
# It showcases advanced enterprise features:
# 1. Multi-objective weighting (e.g. minimizing cost vs minimizing carbon footprint).
# 2. Numerical sensitivity analysis for optimal coefficients and right-hand side limits.
# 3. Solver callback tracking for active log parsing.
# 4. Irreducible Infeasible Set (IIS) conflict finder.
#
# Mathematical Formulation:
#   Minimize (Weighted sum of objectives): 1.0 * Cost_Obj + 2.0 * Carbon_Obj
#            where Cost_Obj = 5.0 * Ship_Plant_A + 8.0 * Ship_Plant_B
#            and Carbon_Obj = 3.0 * Ship_Plant_A + 1.0 * Ship_Plant_B
#            (Combined Target: 11.0 * Ship_Plant_A + 10.0 * Ship_Plant_B)
#   Subject To:
#     Ship_Plant_A <= 50.0                   (Capacity Plant A)
#     Ship_Plant_B <= 60.0                   (Capacity Plant B)
#     Ship_Plant_A >= 80.0 - Ship_Plant_B    (Market Demand Requirement)
#     Ship_Plant_A >= 0.0, Ship_Plant_B >= 0.0

require "../src/optima"

# 1. Create a model
model = Optima::Model.new("SupplyChainNetwork", Optima::ObjectiveSense::Minimize)

# 2. Define decision variables: supply shipments from Plant A and Plant B to a Market
plant_a = model.variable("Ship_Plant_A", lower_bound: 0.0)
plant_b = model.variable("Ship_Plant_B", lower_bound: 0.0)

# 3. Define multi-objectives
# Objective 1: Financial cost. Plant A costs $5/unit, Plant B costs $8/unit.
cost_obj = 5.0 * plant_a + 8.0 * plant_b
model.add_objective(cost_obj, weight: 1.0)

# Objective 2: Environmental impact (Carbon footprint). Plant A emits 3kg CO2/unit, Plant B emits 1kg CO2/unit.
# We weight this objective with a penalty factor of 2.0 to balance cost and emissions.
carbon_obj = 3.0 * plant_a + 1.0 * plant_b
model.add_objective(carbon_obj, weight: 2.0)

# The total objective will automatically be: 1.0 * cost_obj + 2.0 * carbon_obj
# total_obj = (5 + 2*3)*plant_a + (8 + 2*1)*plant_b = 11*plant_a + 10*plant_b

# 4. Add constraints
# Constraint 1: Supply capacity limit for Plant A is 50 units.
c_capacity_a = model.add_constraint(plant_a <= 50.0, name: "Capacity_Plant_A")

# Constraint 2: Supply capacity limit for Plant B is 60 units.
c_capacity_b = model.add_constraint(plant_b <= 60.0, name: "Capacity_Plant_B")

# Constraint 3: Market demand must be met (at least 80 units).
# Shows variables/expressions on both sides of the inequality.
c_demand = model.add_constraint(plant_a >= 80.0 - plant_b, name: "Market_Demand")

# 5. Initialize solver (we use CbcCliSolver as fallback)
solver = Optima::CbcCliSolver.new
solver.log_to_console = false

# 6. Attach solver callback to print messages
solver.on_message = ->(msg : String) {
  puts "[Solver Progress] #{msg.strip}"
  nil
}

puts "--- Solving supply chain model ---"
status = model.solve(solver)
puts "Status: #{status}"

if status.optimal?
  puts "Optimal Objective Value: #{solver.objective_value}"
  puts "Ship from Plant A: #{solver.value(plant_a)} units"
  puts "Ship from Plant B: #{solver.value(plant_b)} units"

  # 7. Run Sensitivity Analysis (Perturbation ranges)
  puts "\n--- Running Sensitivity Analysis ---"
  report = model.sensitivity_analysis(solver, delta: 1e-5)
  
  # Print RHS sensitivity
  report.rhs_ranges.each do |constraint, (obj_minus, obj_plus)|
    puts "Constraint '#{constraint.name}' bounds sensitivity:"
    puts "  - Objective at LHS - delta: #{obj_minus}"
    puts "  - Objective at LHS + delta: #{obj_plus}"
  end
end

# 8. Showcase IIS Finder (Irreducible Infeasible Set)
# We deliberately make the model infeasible by adding a conflicting constraint:
# Total shipment cannot exceed 40 units (which conflicts with demand of at least 80 units).
puts "\n--- Adding conflicting constraint to showcase IIS ---"
c_conflict = model.add_constraint(plant_a <= 40.0 - plant_b, name: "Conflicting_Max_Shipment")

# Find the minimal set of constraints causing this infeasibility
iis = model.compute_iis(solver)
puts "Infeasibility conflict set found. Conflicting constraints:"
iis.each do |c|
  puts " - #{c.name}"
end
