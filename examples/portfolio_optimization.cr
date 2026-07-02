# portfolio_optimization.cr
# This example models a portfolio optimization problem using Markowitz mean-variance theory.
# The goal is to minimize risk (variance of portfolio returns) subject to a minimum target return constraint.
# It demonstrates quadratic objective formulation using the Hessian matrix, and range constraints.
#
# Mathematical Formulation:
#   Minimize: 0.04*w_Apple^2 + 0.03*w_Google^2 + 0.09*w_Tesla^2
#             + 2*(0.015*w_Apple*w_Google + 0.02*w_Apple*w_Tesla + 0.01*w_Google*w_Tesla)
#   Subject To:
#     w_Apple + w_Google + w_Tesla == 1.0       (Budget constraint)
#     0.11 <= 0.12*w_Apple + 0.10*w_Google + 0.18*w_Tesla <= 0.16   (Return target range)
#     0.0 <= w_Apple, w_Google, w_Tesla <= 1.0

require "../src/optima"

# 1. Create a model to minimize portfolio variance (risk)
model = Optima::Model.new("Markowitz Portfolio Optimization", Optima::ObjectiveSense::Minimize)

# 2. Define decision variables: weights of assets in the portfolio (Assets: Apple, Google, Tesla).
# The weights must be between 0.0 and 1.0 (no short-selling).
w_apple = model.variable("weight_Apple", lower_bound: 0.0, upper_bound: 1.0)
w_google = model.variable("weight_Google", lower_bound: 0.0, upper_bound: 1.0)
w_tesla = model.variable("weight_Tesla", lower_bound: 0.0, upper_bound: 1.0)

# Expected asset returns
r_apple = 0.12  # 12% expected return
r_google = 0.10 # 10% expected return
r_tesla = 0.18  # 18% expected return

# 3. Define Quadratic Objective: Minimize portfolio variance
# Variance formula: w^T * Sigma * w, where Sigma is the covariance matrix.
# Covariances:
# Var(Apple) = 0.04, Var(Google) = 0.03, Var(Tesla) = 0.09
# Cov(Apple, Google) = 0.015, Cov(Apple, Tesla) = 0.02, Cov(Google, Tesla) = 0.01
model.hessian[{w_apple, w_apple}] = 0.04
model.hessian[{w_google, w_google}] = 0.03
model.hessian[{w_tesla, w_tesla}] = 0.09

# Off-diagonal elements (symmetric entries are summed by the solver automatically)
model.hessian[{w_apple, w_google}] = 0.015
model.hessian[{w_apple, w_tesla}] = 0.02
model.hessian[{w_google, w_tesla}] = 0.01

# 4. Add Constraints
# Constraint 1: Budget constraint. Total weights must sum exactly to 1.0
model << {w_apple + w_google + w_tesla == 1.0, "Budget_Constraint"}

# Constraint 2: Return target. Portfolio expected return must be at least 11% (0.11), but no more than 16% (0.16)
# Demonstrates Range constraints: lower <= expr <= upper
# (the first comparison must be parenthesized: Crystal desugars bare `a <= b <= c`
# into `(a <= b) && (b <= c)`, which would silently drop the lower bound here)
model << {(0.11 <= r_apple * w_apple + r_google * w_google + r_tesla * w_tesla) <= 0.16, "Target_Return_Range"}

# 5. Initialize Native HiGHS Solver (since HiGHS supports native QP with Hessians)
solver = Optima::HighsSolver.new
solver.log_to_console = false

# 6. Solve
# Note: To run this file, libhighs must be linked.
# Since we are showing compile syntax correctness, we rescue potential loading/linking exceptions.
begin
  status = model.solve(solver)
  puts "Solver Status: #{status}"
  if status.optimal?
    puts "Optimal Portfolio Risk (Variance): #{solver.objective_value}"
    puts "Apple weight: #{(solver.value(w_apple) * 100).round(2)}%"
    puts "Google weight: #{(solver.value(w_google) * 100).round(2)}%"
    puts "Tesla weight: #{(solver.value(w_tesla) * 100).round(2)}%"
  end
rescue ex : Optima::SolverError
  puts "Failed to run HiGHS solver (ensure libhighs is installed): #{ex.message}"
end
