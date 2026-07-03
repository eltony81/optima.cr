# advanced_solver_features.cr
# Demonstrates HighsSolver-specific capabilities beyond a plain solve: tuning solver
# options, detecting a time-limited (as opposed to proven-optimal/infeasible) solve,
# basis-based warm starting, and exact sensitivity ranging via HiGHS's native routine.
#
# A small production-mix LP is used throughout:
#   Maximize: 3 * Widgets + 5 * Gadgets
#   Subject To:
#     Widgets + Gadgets <= 12   (shared production capacity)
#     Widgets, Gadgets in [0, 10]

require "../src/optima"

model = Optima::Model.new("Production Mix", Optima::ObjectiveSense::Maximize)
widgets = model.variable("Widgets", upper_bound: 10.0)
gadgets = model.variable("Gadgets", upper_bound: 10.0)
model.objective = 3 * widgets + 5 * gadgets
capacity = model.add_constraint(widgets + gadgets <= 12.0, "Capacity")

# 1. Solver options: number of threads and presolve mode.
# `threads = 0` (the default) lets HiGHS decide; presolve is "on"/"off"/"choose".
# Setting an invalid presolve string raises Optima::ModelError instead of silently
# falling back to a default, since HiGHS itself rejects it at the C API level.
solver = Optima::HighsSolver.new
solver.threads = 1
solver.presolve = "on"
status = model.solve(solver)
puts "Base solve: #{status}, objective = #{solver.objective_value}"

# 2. Distinguishing "cut short" from "actually unsolvable".
# A hard time_limit on a (here, artificially padded) MIP can terminate before HiGHS
# proves optimality or infeasibility - SolverStatus::UserAborted signals exactly that,
# rather than collapsing into the same Unknown a genuinely inconclusive solve would give.
mip_model = Optima::Model.new("Padded Knapsack", Optima::ObjectiveSense::Maximize)
items = (0...40).map { |i| mip_model.variable("item_#{i}", category: Optima::VariableType::Binary) }
mip_model.objective = Optima.lpSum(items.map_with_index { |it, i| it * (i + 1) })
mip_model << (Optima.lpDot(items.map_with_index { |_, i| (i * 3 % 17 + 1).to_f64 }, items) <= 60.0)

tight_solver = Optima::HighsSolver.new
tight_solver.time_limit = 0.0001
tight_status = mip_model.solve(tight_solver)
puts "Time-limited MIP solve status: #{tight_status} (UserAborted means 'ran out of time', not 'infeasible')"

# 3. Basis-based warm starting.
# Capturing the optimal basis and replaying it on a fresh solve of a *similar* model
# is the standard, more effective alternative to seeding a raw solution vector
# (HighsSolver#set_solution) - useful when re-solving after a small perturbation.
basis = solver.get_basis(model)
warm_solver = Optima::HighsSolver.new
warm_solver.warm_start_basis = basis
warm_status = model.solve(warm_solver)
puts "Warm-started re-solve: #{warm_status}, objective = #{warm_solver.objective_value}"

# 4. Exact sensitivity ranging (HighsSolver#sensitivity_analysis).
# Unlike Model#sensitivity_analysis (which perturbs each coefficient by +/-delta and
# re-solves to approximate a local derivative), this calls HiGHS's native ranging
# routine once and returns the textbook [min, max] range each objective coefficient /
# constraint RHS can take without changing the optimal basis.
report = solver.sensitivity_analysis(model)
widgets_lo, widgets_hi = report.obj_coefficient_ranges[widgets]
puts "Widgets' objective coefficient can range from #{widgets_lo} to #{widgets_hi} " \
     "before the optimal basis would change"
capacity_lo, capacity_hi = report.rhs_ranges[capacity]
puts "Capacity's RHS can range from #{capacity_lo} to #{capacity_hi} " \
     "before the optimal basis would change"
