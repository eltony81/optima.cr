# facility_location.cr
# This example models a Facility Location Problem where a business must decide:
# 1. Which warehouses to open (binary decisions: 1 = open, 0 = close).
# 2. How to allocate client demands to open warehouses to minimize shipping and setup costs.
# It demonstrates binary variables, variable dictionaries, lpSum, and lpDot.
#
# Mathematical Formulation:
#   Minimize: sum_{w} (setup_cost_w * y_w) + sum_{w, c} (shipping_cost_w_c * x_w_c)
#   Subject To:
#     sum_{w} (x_w_c) == 1.0                forall c (Client Demand Satisfaction)
#     x_w_c <= y_w                          forall w, c (Capacity Link: ship only from open warehouses)
#     y_w in {0, 1}                         forall w
#     0.0 <= x_w_c <= 1.0                   forall w, c

require "../src/optima"

# 1. Define problem parameters
warehouses = ["Milan", "Rome", "Naples"]
clients = ["Client_1", "Client_2", "Client_3", "Client_4"]

# Cost to open each warehouse
setup_costs = {"Milan" => 1000.0, "Rome" => 1200.0, "Naples" => 900.0}

# Cost to ship from warehouse to client
shipping_costs = {
  {"Milan", "Client_1"} => 4.0, {"Milan", "Client_2"} => 5.0, {"Milan", "Client_3"} => 6.0, {"Milan", "Client_4"} => 8.0,
  {"Rome", "Client_1"} => 6.0, {"Rome", "Client_2"} => 4.0, {"Rome", "Client_3"} => 3.0, {"Rome", "Client_4"} => 5.0,
  {"Naples", "Client_1"} => 7.0, {"Naples", "Client_2"} => 6.0, {"Naples", "Client_3"} => 4.0, {"Naples", "Client_4"} => 3.0,
}

# 2. Create the model
model = Optima::Model.new("Warehouse_Facility_Location", Optima::ObjectiveSense::Minimize)

# 3. Create decision variables
# Binary variable: y[w] = 1 if warehouse w is opened, else 0
y = model.variable_dict("y", warehouses, category: Optima::VariableType::Binary)

# Continuous variables: x[w, c] = amount of demand shipped from warehouse w to client c (bounds [0, 1] for percentage)
# We represent indices as a flat array of Tuples
shipping_indices = [] of Tuple(String, String)
warehouses.each do |w|
  clients.each do |c|
    shipping_indices << {w, c}
  end
end
x = model.variable_dict("x", shipping_indices, lower_bound: 0.0, upper_bound: 1.0)

# 4. Define Objective Function: Minimize Setup Costs + Shipping Costs
# setup_cost_expr = y["Milan"] * 1000 + y["Rome"] * 1200 + y["Naples"] * 900
setup_terms = warehouses.map { |w| y[w] * setup_costs[w] }
setup_expr = Optima.lpSum(setup_terms)

# shipping_cost_expr = shipping_costs[w, c] * x[w, c]
shipping_terms = shipping_indices.map { |idx| x[idx] * shipping_costs[idx] }
shipping_expr = Optima.lpSum(shipping_terms)

model.objective = setup_expr + shipping_expr

# 5. Add Constraints
# Constraint 1: Customer satisfaction. The demand of each client must be fully met (sum of ship % from all warehouses = 1)
clients.each do |c|
  terms = warehouses.map { |w| x[{w, c}] }
  model << {Optima.lpSum(terms) == 1.0, "Demand_Satisfaction_#{c}"}
end

# Constraint 2: Warehouse capacity. We cannot ship from a warehouse unless it is opened.
# ship % from warehouse w to client c <= y[w]
warehouses.each do |w|
  clients.each do |c|
    model << {x[{w, c}] <= y[w], "Capacity_Link_#{w}_#{c}"}
  end
end

# 6. Initialize solver and solve
solver = Optima::CbcCliSolver.new
solver.log_to_console = false
status = model.solve(solver)

puts "Status: #{status}"
if status.optimal?
  puts "Total Cost: $#{solver.objective_value}"
  puts "\nWarehouse decisions:"
  warehouses.each do |w|
    decision = solver.value(y[w]) > 0.5 ? "OPEN" : "CLOSED"
    puts " - #{w}: #{decision}"
  end

  puts "\nAllocation plan:"
  shipping_indices.each do |idx|
    val = solver.value(x[idx])
    if val > 0.01
      puts " - Ship #{(val * 100).round}% of #{idx[1]} demand from #{idx[0]}"
    end
  end
end
