require "log"
require "./optima/exceptions"
require "./optima/solver"
require "./optima/variable"
require "./optima/expression"
require "./optima/quadratic_expression"
require "./optima/sensitivity_report"
require "./optima/constraint"
require "./optima/vectorized"
require "./optima/model"
require "./optima/native/highs"
require "./optima/native/highs_solver"
require "./optima/cbc_cli_solver"
require "./optima/glpk_cli_solver"
require "./optima/solver_pool"

module Optima
  Log     = ::Log.for("optima")
  VERSION = "0.2.0"
end
