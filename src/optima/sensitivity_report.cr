module Optima
  class SensitivityReport
    property obj_coefficient_ranges : Hash(Variable, Tuple(Float64, Float64))
    property rhs_ranges : Hash(Constraint, Tuple(Float64, Float64))

    def initialize
      @obj_coefficient_ranges = ({} of Variable => Tuple(Float64, Float64)).compare_by_identity
      @rhs_ranges = {} of Constraint => Tuple(Float64, Float64)
    end
  end
end
