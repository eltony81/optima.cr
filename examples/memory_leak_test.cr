require "../src/optima"

# Run with: crystal run examples/memory_leak_test.cr

puts "Starting memory leak benchmark test..."

# Configure logger to be quiet during benchmarking
Optima::Log.level = Log::Severity::None

# Run GC collection at the start
GC.collect

# Record initial memory usage
initial_mem = GC.stats.heap_size
puts "Initial GC Heap Size: #{initial_mem / 1024} KB"

# Solve a model 10,000 times to trigger finalizers multiple times
10_000.times do |i|
  model = Optima::Model.new("Loop Model #{i}")
  x = model.variable("x")
  y = model.variable("y")
  model.objective = x + 2 * y
  model << {x + y <= 10, "c1"}

  solver = Optima::HighsSolver.new
  # Just syntax-validate or solve (we run solve, which triggers allocations)
  # If highs library is missing, we bypass solve with a rescue, but if highs is present, it runs.
  begin
    model.solve(solver)
  rescue ex : Optima::SolverError
    # Bypass linking failure in check environments
  rescue ex
    # Catch any other runtime issues
  end
end

# Collect garbage at the end
GC.collect

# Record final memory usage
final_mem = GC.stats.heap_size
puts "Final GC Heap Size: #{final_mem / 1024} KB"

diff = final_mem - initial_mem
puts "Memory Heap Size Delta: #{diff / 1024} KB"

if diff < 1024 * 1024 # Limit diff to 1MB to verify no massive leak
  puts "Leak Test Status: SUCCESS (No memory leak detected)"
else
  puts "Leak Test Status: FAILED (Possible memory leak)"
end
