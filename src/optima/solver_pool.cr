require "mutex"

module Optima
  # A thread-safe pool of `HighsSolver` instances to allow concurrent optimization
  # in multi-threaded Crystal applications.
  class SolverPool
    @pool : Deque(HighsSolver)
    @mutex : Mutex
    @capacity : Int32

    def initialize(@capacity : Int32 = 4)
      @pool = Deque(HighsSolver).new
      @mutex = Mutex.new
      @capacity.times { @pool << HighsSolver.new }
    end

    # Checks out a solver instance from the pool.
    # If the pool is empty, it returns a new instance.
    def checkout : HighsSolver
      @mutex.synchronize do
        if @pool.empty?
          HighsSolver.new
        else
          @pool.shift
        end
      end
    end

    # Checks in a solver instance back into the pool.
    def checkin(solver : HighsSolver)
      @mutex.synchronize do
        if @pool.size < @capacity
          @pool << solver
        end
      end
    end

    # Yields a solver from the pool and automatically checks it back in
    # after the block execution completes.
    def use(&block : HighsSolver -> T) : T forall T
      solver = checkout
      begin
        yield solver
      ensure
        checkin(solver)
      end
    end
  end
end
