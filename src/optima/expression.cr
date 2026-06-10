module Optima
  class Expression
    include JSON::Serializable
    property terms : Hash(Variable, Float64)
    property constant : Float64

    def initialize(terms : Hash(Variable, Float64), @constant : Float64 = 0.0)
      @terms = terms.dup
    end

    def initialize(var : Variable, coeff : Float64 = 1.0, @constant : Float64 = 0.0)
      @terms = {var => coeff}
    end

    def initialize(@constant : Float64 = 0.0)
      @terms = Hash(Variable, Float64).new
    end

    def self.new(other : Expression)
      other
    end

    def +(other : Variable) : Expression
      res = Expression.new(terms, constant)
      res.terms[other] = res.terms.fetch(other, 0.0) + 1.0
      res
    end

    def +(other : Expression) : Expression
      res = Expression.new(terms, constant + other.constant)
      other.terms.each do |var, coeff|
        res.terms[var] = res.terms.fetch(var, 0.0) + coeff
      end
      res
    end

    def +(other : Number) : Expression
      Expression.new(terms, constant + other.to_f64)
    end

    def -(other : Variable) : Expression
      res = Expression.new(terms, constant)
      res.terms[other] = res.terms.fetch(other, 0.0) - 1.0
      res
    end

    def -(other : Expression) : Expression
      res = Expression.new(terms, constant - other.constant)
      other.terms.each do |var, coeff|
        res.terms[var] = res.terms.fetch(var, 0.0) - coeff
      end
      res
    end

    def -(other : Number) : Expression
      Expression.new(terms, constant - other.to_f64)
    end

    def *(coeff : Number) : Expression
      c = coeff.to_f64
      new_terms = Hash(Variable, Float64).new
      terms.each do |var, val|
        new_terms[var] = val * c
      end
      Expression.new(new_terms, constant * c)
    end

    def *(other : Variable) : QuadraticExpression
      other * self
    end

    def - : Expression
      self * -1.0
    end

    def <=(other : Variable) : Constraint
      self <= Expression.new(other)
    end

    def <=(other : Number) : Constraint
      self <= Expression.new(other.to_f64)
    end

    def <=(other : Expression) : Constraint
      Constraint.new(self - other, ConstraintType::LessThanOrEqual)
    end

    def >=(other : Variable) : Constraint
      self >= Expression.new(other)
    end

    def >=(other : Number) : Constraint
      self >= Expression.new(other.to_f64)
    end

    def >=(other : Expression) : Constraint
      Constraint.new(self - other, ConstraintType::GreaterThanOrEqual)
    end

    def ==(other : Variable) : Constraint
      self == Expression.new(other)
    end

    def ==(other : Number) : Constraint
      self == Expression.new(other.to_f64)
    end

    def ==(other : Expression) : Constraint
      Constraint.new(self - other, ConstraintType::Equal)
    end

    def to_s(io : IO)
      first = true
      terms.each do |var, coeff|
        if coeff == 0.0
          next
        end
        if first
          if coeff == 1.0
            io << var.name
          elsif coeff == -1.0
            io << "-" << var.name
          else
            io << coeff << " * " << var.name
          end
          first = false
        else
          if coeff > 0.0
            io << " + "
            if coeff == 1.0
              io << var.name
            else
              io << coeff << " * " << var.name
            end
          else
            io << " - "
            if coeff == -1.0
              io << var.name
            else
              io << coeff.abs << " * " << var.name
            end
          end
        end
      end
      if constant != 0.0 || first
        if first
          io << constant
        elsif constant > 0.0
          io << " + " << constant
        else
          io << " - " << constant.abs
        end
      end
    end
    def sparsify!(epsilon : Float64 = 1e-9) : self
      @terms.reject! { |_, coeff| coeff.abs < epsilon }
      self
    end
  end
end
