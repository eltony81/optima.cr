module Optima
  enum ConstraintType
    LessThanOrEqual
    GreaterThanOrEqual
    Equal
  end

  class Constraint
    include JSON::Serializable
    property id : Int32?
    property name : String?
    property expr : Expression | QuadraticExpression
    property constraint_type : ConstraintType
    property range_upper : Float64?

    def initialize(@expr : Expression | QuadraticExpression, @constraint_type : ConstraintType, @name : String? = nil)
    end

    def self.new(other : Constraint)
      other
    end

    def <=(upper : Number) : self
      if @constraint_type == ConstraintType::GreaterThanOrEqual
        @range_upper = upper.to_f64
      else
        raise "Range constraint upper bound can only be chained to a >= (lower bound) constraint"
      end
      self
    end

    def to_s(io : IO)
      if n = name
        io << n << ": "
      end

      # Print in standard form for readability
      # e.g. 2*x + 3*y <= -constant
      io << expr.to_s
      case constraint_type
      when ConstraintType::LessThanOrEqual
        io << " <= 0"
      when ConstraintType::GreaterThanOrEqual
        io << " >= 0"
      when ConstraintType::Equal
        io << " == 0"
      end
    end
  end
end
