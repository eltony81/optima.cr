require "json"

module Optima
  enum VariableType
    Continuous = 0
    Integer = 1
    SemiContinuous = 2
    Binary = 3
    SemiInteger = 4
  end

  def self.lpSum(items : Enumerable(Variable | Expression | Number)) : Expression
    res = Expression.new
    items.each do |item|
      case item
      when Variable
        res += item
      when Expression
        res += item
      when Number
        res += item
      end
    end
    res
  end

  def self.lpDot(coeffs : Enumerable(Number), vars : Enumerable(Variable)) : Expression
    res = Expression.new
    coeffs.zip(vars) do |coeff, var|
      res += var * coeff
    end
    res
  end

  class Variable
    include JSON::Serializable

    property id : Int32
    property name : String
    property var_type : VariableType
    property lower_bound : Float64
    property upper_bound : Float64

    def initialize(@id : Int32, @name : String, @var_type : VariableType = VariableType::Continuous, @lower_bound : Float64 = 0.0, @upper_bound : Float64 = Float64::INFINITY)
    end

    def self.new(other : Variable)
      other
    end

    def to_json_object_key : String
      name
    end

    def +(other : Variable) : Expression
      Expression.new(self) + other
    end

    def +(other : Expression) : Expression
      other + self
    end

    def +(other : Number) : Expression
      Expression.new(self) + other
    end

    def -(other : Variable) : Expression
      Expression.new(self) - other
    end

    def -(other : Expression) : Expression
      Expression.new(self) - other
    end

    def -(other : Number) : Expression
      Expression.new(self) - other
    end

    def *(coeff : Number) : Expression
      Expression.new({self => coeff.to_f64})
    end

    def *(other : Variable) : QuadraticExpression
      QuadraticExpression.new(self, other, 1.0)
    end

    def *(other : Expression) : QuadraticExpression
      res = QuadraticExpression.new
      other.terms.each do |var, coeff|
        res.quad_terms[{self, var}] = res.quad_terms.fetch({self, var}, 0.0) + coeff
      end
      if other.constant != 0.0
        res.terms[self] = other.constant
      end
      res
    end

    def - : Expression
      Expression.new({self => -1.0})
    end

    def <=(other : Variable | Expression | Number) : Constraint
      Expression.new(self) <= other
    end

    def >=(other : Variable | Expression | Number) : Constraint
      Expression.new(self) >= other
    end

    def ==(other : Variable | Expression | Number) : Constraint
      Expression.new(self) == other
    end
  end
end

struct Number
  def *(other : Optima::Variable) : Optima::Expression
    other * self
  end

  def *(other : Optima::Expression) : Optima::Expression
    other * self
  end

  def +(other : Optima::Variable) : Optima::Expression
    Optima::Expression.new(other) + self
  end

  def +(other : Optima::Expression) : Optima::Expression
    other + self
  end

  def -(other : Optima::Variable) : Optima::Expression
    Optima::Expression.new(other) * -1.0 + self
  end

  def -(other : Optima::Expression) : Optima::Expression
    other * -1.0 + self
  end
  def <=(other : Optima::Variable) : Optima::Constraint
    Optima::Expression.new(other) >= self
  end

  def <=(other : Optima::Expression) : Optima::Constraint
    other >= self
  end

  def >=(other : Optima::Variable) : Optima::Constraint
    Optima::Expression.new(other) <= self
  end

  def >=(other : Optima::Expression) : Optima::Constraint
    other <= self
  end

  def ==(other : Optima::Variable) : Optima::Constraint
    Optima::Expression.new(other) == self
  end

  def ==(other : Optima::Expression) : Optima::Constraint
    other == self
  end
end
