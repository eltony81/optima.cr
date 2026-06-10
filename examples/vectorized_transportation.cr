# vectorized_transportation.cr
# This example models a classic Transportation Problem using vectorized matrix modeling with `num.cr`.
# A manufacturer wants to ship products from two supply plants (Plant_0, Plant_1) to three distribution warehouses
# (Wh_0, Wh_1, Wh_2) at the lowest shipping cost while satisfying plant supply limits and warehouse demands.
#
# Mathematical Formulation:
#   Minimize: 2.0*x_0 + 4.0*x_1 + 5.0*x_2 + 3.0*x_3 + 1.0*x_4 + 6.0*x_5
#   Subject To:
#     x_0 + x_1 + x_2 <= 100.0                       (Plant_0 capacity limit)
#     x_3 + x_4 + x_5 <= 150.0                       (Plant_1 capacity limit)
#     x_0 + x_3 >= 80.0                              (Wh_0 demand limit)
#     x_1 + x_4 >= 70.0                              (Wh_1 demand limit)
#     x_2 + x_5 >= 90.0                              (Wh_2 demand limit)
#     x_i >= 0.0                                     forall i in {0..5}

require "num"
require "../src/optima"

# 1. Create a model to minimize total shipping cost
model = Optima::Model.new("Vectorized Transportation", Optima::ObjectiveSense::Minimize)

# 2. Define indices: 2 plants (i = 0, 1) and 3 warehouses (j = 0, 1, 2)
# We create a 1D Tensor of 6 shipping variables representing Plant_i -> Wh_j shipments.
# x[0] = Plant_0->Wh_0, x[1] = Plant_0->Wh_1, x[2] = Plant_0->Wh_2
# x[3] = Plant_1->Wh_0, x[4] = Plant_1->Wh_1, x[5] = Plant_1->Wh_2
x = model.variable_vector("ship", size: 6)

# 3. Define the shipping cost vector for all 6 routes
# Plant_0 shipping costs to Whs: $2.0, $4.0, $5.0
# Plant_1 shipping costs to Whs: $3.0, $1.0, $6.0
costs = Tensor.from_array([
  2.0, 4.0, 5.0,  # Plant_0 routes
  3.0, 1.0, 6.0   # Plant_1 routes
])

# Objective: Minimize total cost (manually sum products of costs and variables)
model.objective = (0...6).map { |idx| costs.to_unsafe[idx] * x.to_unsafe[idx] }.reduce { |sum, term| sum + term }

# 4. Define Supply Constraints (Plant Capacity limits)
# Plant_0 capacity: 100 units. Route variables are x[0] + x[1] + x[2] <= 100
# Plant_1 capacity: 150 units. Route variables are x[3] + x[4] + x[5] <= 150
# We can represent this with a coefficient matrix of shape 2x6:
supply_coefs = Tensor.from_array([
  [1.0, 1.0, 1.0, 0.0, 0.0, 0.0], # Plant_0 shipment sum
  [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]  # Plant_1 shipment sum
])
plant_outflow = supply_coefs * x
plant_capacities = Tensor.from_array([100.0, 150.0])
model << (plant_outflow <= plant_capacities)

# 5. Define Demand Constraints (Warehouse Demand requirements)
# Wh_0 demand: 80 units. Requirement: x[0] + x[3] >= 80
# Wh_1 demand: 70 units. Requirement: x[1] + x[4] >= 70
# Wh_2 demand: 90 units. Requirement: x[2] + x[5] >= 90
# We represent this with a coefficient matrix of shape 3x6:
demand_coefs = Tensor.from_array([
  [1.0, 0.0, 0.0, 1.0, 0.0, 0.0], # Wh_0 incoming sum
  [0.0, 1.0, 0.0, 0.0, 1.0, 0.0], # Wh_1 incoming sum
  [0.0, 0.0, 1.0, 0.0, 0.0, 1.0]  # Wh_2 incoming sum
])
wh_inflow = demand_coefs * x
wh_demands = Tensor.from_array([80.0, 70.0, 90.0])
model << (wh_inflow >= wh_demands)

# 6. Initialize solver and solve
solver = Optima::CbcCliSolver.new
solver.log_to_console = false

status = model.solve(solver)
puts "Status: #{status}"

if status.optimal?
  puts "Optimal Transportation Cost: $#{solver.objective_value.round(2)}"
  puts "\nOptimal Shipment Matrix (Plants \\ Warehouses):"
  puts "          Wh_0    Wh_1    Wh_2"
  puts "Plant_0:  #{solver.value(x.to_unsafe[0]).round(1)}     #{solver.value(x.to_unsafe[1]).round(1)}     #{solver.value(x.to_unsafe[2]).round(1)}"
  puts "Plant_1:  #{solver.value(x.to_unsafe[3]).round(1)}     #{solver.value(x.to_unsafe[4]).round(1)}     #{solver.value(x.to_unsafe[5]).round(1)}"
end
