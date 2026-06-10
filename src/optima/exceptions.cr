module Optima
  # Base exception class for all Optima.cr errors.
  class Error < Exception; end

  # Exception raised when a solver encounters an error.
  class SolverError < Error; end

  # Exception raised when a model configuration or formulation is invalid.
  class ModelError < Error; end

  # Exception raised when trying to retrieve values from an unsolved model.
  class NotSolvedError < Error; end
end
