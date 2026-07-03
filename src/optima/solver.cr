module Optima
  # Represents the optimization direction.
  enum ObjectiveSense
    Minimize =  1
    Maximize = -1
  end

  # Represents the result of the optimization solve.
  enum SolverStatus
    Optimal
    Infeasible
    Unbounded
    InfeasibleOrUnbounded
    # Solve was cut short before proving optimality/infeasibility - e.g. HighsSolver's
    # time_limit/mip_gap/iteration/solution limits, or CBC's "Stopped on time/user".
    UserAborted
    ModelError
    NotSolved
    Unknown
  end

  # Common interface that all solver backends must implement.
  abstract class Solver
    # Solve the given model and return the solver status.
    abstract def solve(model : Model) : SolverStatus

    # Get the solved primal value of a variable.
    abstract def value(variable : Variable) : Float64

    # Get the solved objective value of the model.
    abstract def objective_value : Float64
  end
end
