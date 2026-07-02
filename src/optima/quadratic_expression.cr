struct Tuple
  # Tuple(Variable, Variable) is used as a Hash key (QuadraticExpression#quad_terms,
  # Model#hessian). Hash#compare_by_identity can't help here since Tuple itself has no
  # object_id, and Variable#== builds a DSL Constraint rather than a Bool — so compare
  # by variable identity directly instead of falling through to Variable#==.
  def ==(other : self)
    {% if T == {Optima::Variable, Optima::Variable} %}
      self[0].same?(other[0]) && self[1].same?(other[1])
    {% else %}
      previous_def
    {% end %}
  end
end

module Optima
  class QuadraticExpression
    property terms : Hash(Variable, Float64)
    property quad_terms : Hash(Tuple(Variable, Variable), Float64)
    property constant : Float64

    def initialize(terms : Hash(Variable, Float64), quad_terms : Hash(Tuple(Variable, Variable), Float64), @constant : Float64 = 0.0)
      @terms = terms.dup.compare_by_identity
      @quad_terms = quad_terms.dup
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "terms" do
          json.object do
            @terms.each do |var, coeff|
              json.field var.name, coeff
            end
          end
        end
        json.field "quad_terms" do
          json.array do
            @quad_terms.each do |(v1, v2), coeff|
              json.object do
                json.field "var1", v1.name
                json.field "var2", v2.name
                json.field "coeff", coeff
              end
            end
          end
        end
        json.field "constant", @constant
      end
    end

    def self.new(pull : JSON::PullParser)
      terms = Hash(Variable, Float64).new.compare_by_identity
      quad_terms = Hash(Tuple(Variable, Variable), Float64).new
      constant = 0.0

      pull.read_object do |key|
        case key
        when "terms"
          pull.read_object do |var_name|
            terms[Variable.new(-1, var_name)] = pull.read_float
          end
        when "quad_terms"
          pull.read_array do
            var1_name = ""
            var2_name = ""
            coeff = 0.0
            pull.read_object do |k|
              case k
              when "var1"  then var1_name = pull.read_string
              when "var2"  then var2_name = pull.read_string
              when "coeff" then coeff = pull.read_float
              else              pull.skip
              end
            end
            quad_terms[{Variable.new(-1, var1_name), Variable.new(-1, var2_name)}] = coeff
          end
        when "constant"
          constant = pull.read_float
        else
          pull.skip
        end
      end

      new(terms, quad_terms, constant)
    end

    def initialize(var1 : Variable, var2 : Variable, coeff : Float64 = 1.0)
      @terms = Hash(Variable, Float64).new.compare_by_identity
      @quad_terms = Hash(Tuple(Variable, Variable), Float64).new
      @quad_terms[{var1, var2}] = coeff
      @constant = 0.0
    end

    def initialize(@constant : Float64 = 0.0)
      @terms = Hash(Variable, Float64).new.compare_by_identity
      @quad_terms = Hash(Tuple(Variable, Variable), Float64).new
    end

    def +(other : Variable) : QuadraticExpression
      res = QuadraticExpression.new(terms, quad_terms, constant)
      res.terms[other] = res.terms.fetch(other, 0.0) + 1.0
      res
    end

    def +(other : Expression) : QuadraticExpression
      res = QuadraticExpression.new(terms, quad_terms, constant + other.constant)
      other.terms.each do |var, coeff|
        res.terms[var] = res.terms.fetch(var, 0.0) + coeff
      end
      res
    end

    def +(other : QuadraticExpression) : QuadraticExpression
      res = QuadraticExpression.new(terms, quad_terms, constant + other.constant)
      other.terms.each do |var, coeff|
        res.terms[var] = res.terms.fetch(var, 0.0) + coeff
      end
      other.quad_terms.each do |key, coeff|
        res.quad_terms[key] = res.quad_terms.fetch(key, 0.0) + coeff
      end
      res
    end

    def +(other : Number) : QuadraticExpression
      QuadraticExpression.new(terms, quad_terms, constant + other.to_f64)
    end

    def -(other : Variable) : QuadraticExpression
      res = QuadraticExpression.new(terms, quad_terms, constant)
      res.terms[other] = res.terms.fetch(other, 0.0) - 1.0
      res
    end

    def -(other : Expression) : QuadraticExpression
      res = QuadraticExpression.new(terms, quad_terms, constant - other.constant)
      other.terms.each do |var, coeff|
        res.terms[var] = res.terms.fetch(var, 0.0) - coeff
      end
      res
    end

    def -(other : QuadraticExpression) : QuadraticExpression
      res = QuadraticExpression.new(terms, quad_terms, constant - other.constant)
      other.terms.each do |var, coeff|
        res.terms[var] = res.terms.fetch(var, 0.0) - coeff
      end
      other.quad_terms.each do |key, coeff|
        res.quad_terms[key] = res.quad_terms.fetch(key, 0.0) - coeff
      end
      res
    end

    def -(other : Number) : QuadraticExpression
      QuadraticExpression.new(terms, quad_terms, constant - other.to_f64)
    end

    def *(coeff : Number) : QuadraticExpression
      c = coeff.to_f64
      new_terms = Hash(Variable, Float64).new.compare_by_identity
      terms.each { |var, val| new_terms[var] = val * c }

      new_quad = Hash(Tuple(Variable, Variable), Float64).new
      quad_terms.each { |key, val| new_quad[key] = val * c }

      QuadraticExpression.new(new_terms, new_quad, constant * c)
    end

    def - : QuadraticExpression
      self * -1.0
    end

    def <=(other : Variable | Expression | QuadraticExpression | Number) : Constraint
      Constraint.new(self - other, ConstraintType::LessThanOrEqual)
    end

    def >=(other : Variable | Expression | QuadraticExpression | Number) : Constraint
      Constraint.new(self - other, ConstraintType::GreaterThanOrEqual)
    end

    def ==(other : Variable | Expression | QuadraticExpression | Number) : Constraint
      Constraint.new(self - other, ConstraintType::Equal)
    end

    def to_s(io : IO)
      # Print linear terms
      expr = Expression.new(terms, constant)
      expr.to_s(io)

      # Print quadratic terms
      quad_terms.each do |(v1, v2), coeff|
        if coeff == 0.0
          next
        end
        io << (coeff > 0.0 ? " + " : " - ")
        val = coeff.abs
        if val == 1.0
          io << v1.name << " * " << v2.name
        else
          io << val << " * " << v1.name << " * " << v2.name
        end
      end
    end
  end
end
