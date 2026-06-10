require "num"

module Optima
  # Convenient aliases for Vectorized Modeling
  alias VariableTensor = Tensor(Variable, CPU(Variable))
  alias ExpressionTensor = Tensor(Expression, CPU(Expression))
  alias ConstraintTensor = Tensor(Constraint, CPU(Constraint))
  alias FloatTensor = Tensor(Float64, CPU(Float64))

  def self.matmul(matrix : Tensor(Float64, CPU(Float64)), vector : Tensor(Variable, CPU(Variable))) : Tensor(Expression, CPU(Expression))
    unless matrix.rank == 2 && vector.rank == 1
      raise "Matrix multiplication requires a 2D matrix and a 1D vector"
    end
    m = matrix.shape[0]
    n = matrix.shape[1]
    unless vector.shape[0] == n
      raise "Dimension mismatch: matrix columns (#{n}) must match vector size (#{vector.shape[0]})"
    end

    Tensor(Expression, CPU(Expression)).new([m]) do |i|
      expr = Expression.new
      (0...n).each do |j|
        coeff = matrix.to_unsafe[matrix.offset + i * matrix.strides[0] + j * matrix.strides[1]]
        v = vector.to_unsafe[vector.offset + j * vector.strides[0]]
        expr += v * coeff
      end
      expr.as(Expression)
    end
  end

  def self.matmul(matrix : Tensor(Float64, CPU(Float64)), vector : Tensor(Expression, CPU(Expression))) : Tensor(Expression, CPU(Expression))
    unless matrix.rank == 2 && vector.rank == 1
      raise "Matrix multiplication requires a 2D matrix and a 1D vector"
    end
    m = matrix.shape[0]
    n = matrix.shape[1]
    unless vector.shape[0] == n
      raise "Dimension mismatch: matrix columns (#{n}) must match vector size (#{vector.shape[0]})"
    end

    Tensor(Expression, CPU(Expression)).new([m]) do |i|
      expr = Expression.new
      (0...n).each do |j|
        coeff = matrix.to_unsafe[matrix.offset + i * matrix.strides[0] + j * matrix.strides[1]]
        v = vector.to_unsafe[vector.offset + j * vector.strides[0]]
        expr += v * coeff
      end
      expr.as(Expression)
    end
  end
end

class Tensor(T, S)
  def *(other : Tensor(Optima::Variable, CPU(Optima::Variable)))
    {% if T == Float64 %}
      Optima.matmul(self, other)
    {% else %}
      previous_def
    {% end %}
  end

  def *(other : Tensor(Optima::Expression, CPU(Optima::Expression)))
    {% if T == Float64 %}
      Optima.matmul(self, other)
    {% else %}
      previous_def
    {% end %}
  end

  def <=(other : Tensor(U, CPU(U)) | Number) : Tensor(Optima::Constraint, CPU(Optima::Constraint)) forall U
    {% if T == Optima::Expression || T == Optima::Variable %}
      if other.is_a?(Number)
        Tensor(Optima::Constraint, CPU(Optima::Constraint)).new(self.shape) do |idx|
          lhs = self.to_unsafe[self.offset + idx * self.strides[0]]
          (lhs <= other).as(Optima::Constraint)
        end
      else
        unless self.shape == other.shape
          raise "Dimension mismatch in element-wise comparison"
        end
        Tensor(Optima::Constraint, CPU(Optima::Constraint)).new(self.shape) do |idx|
          lhs = self.to_unsafe[self.offset + idx * self.strides[0]]
          rhs = other.to_unsafe[other.offset + idx * other.strides[0]]
          (lhs <= rhs).as(Optima::Constraint)
        end
      end
    {% else %}
      previous_def
    {% end %}
  end

  def >=(other : Tensor(U, CPU(U)) | Number) : Tensor(Optima::Constraint, CPU(Optima::Constraint)) forall U
    {% if T == Optima::Expression || T == Optima::Variable %}
      if other.is_a?(Number)
        Tensor(Optima::Constraint, CPU(Optima::Constraint)).new(self.shape) do |idx|
          lhs = self.to_unsafe[self.offset + idx * self.strides[0]]
          (lhs >= other).as(Optima::Constraint)
        end
      else
        unless self.shape == other.shape
          raise "Dimension mismatch in element-wise comparison"
        end
        Tensor(Optima::Constraint, CPU(Optima::Constraint)).new(self.shape) do |idx|
          lhs = self.to_unsafe[self.offset + idx * self.strides[0]]
          rhs = other.to_unsafe[other.offset + idx * other.strides[0]]
          (lhs >= rhs).as(Optima::Constraint)
        end
      end
    {% else %}
      previous_def
    {% end %}
  end

  def ==(other : Tensor(U, CPU(U)) | Number) : Tensor(Optima::Constraint, CPU(Optima::Constraint)) forall U
    {% if T == Optima::Expression || T == Optima::Variable %}
      if other.is_a?(Number)
        Tensor(Optima::Constraint, CPU(Optima::Constraint)).new(self.shape) do |idx|
          lhs = self.to_unsafe[self.offset + idx * self.strides[0]]
          (lhs == other).as(Optima::Constraint)
        end
      else
        unless self.shape == other.shape
          raise "Dimension mismatch in element-wise comparison"
        end
        Tensor(Optima::Constraint, CPU(Optima::Constraint)).new(self.shape) do |idx|
          lhs = self.to_unsafe[self.offset + idx * self.strides[0]]
          rhs = other.to_unsafe[other.offset + idx * other.strides[0]]
          (lhs == rhs).as(Optima::Constraint)
        end
      end
    {% else %}
      previous_def
    {% end %}
  end
end
