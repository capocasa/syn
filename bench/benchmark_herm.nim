import src/syn
import std/[times, math, random, strformat]

proc benchmark() =
  let tableSize = 1024
  var table = newSeq[float32](tableSize + 4)
  
  # Generate simple test data  
  for i in 0..<(tableSize + 4):
    table[i] = sin(2.0 * PI * float32(i) / float32(tableSize))
  
  let numPhases = 8192  # Must be divisible by 16 for optimized AVX2
  var phases = newSeq[float32](numPhases)
  
  # Generate random phases between 0 and 0.999
  randomize()
  for i in 0..<numPhases:
    phases[i] = rand(0.999f32)
  
  echo "Benchmarking optimized hermite interpolation with ", numPhases, " phases"
  echo "Table size: ", tableSize
  echo "Processing 16 values per iteration with vectorized gather"
  
  # Benchmark linear version
  let startLinear = cpuTime()
  var linearResults = newSeq[float32](numPhases)
  for iter in 0..<100:
    for i in 0..<numPhases:
      linearResults[i] = herm(table, phases[i])
  let endLinear = cpuTime()
  let linearTime = endLinear - startLinear
  
  # Benchmark AVX2 version
  let startAvx = cpuTime()
  var avxResults: seq[float32]
  for iter in 0..<100:
    avxResults = herm(table, phases)
  let endAvx = cpuTime()
  let avxTime = endAvx - startAvx
  
  echo "\nResults:"
  echo &"Linear version: {linearTime:.4f} seconds"
  echo &"AVX2 version:   {avxTime:.4f} seconds"
  echo &"Speedup:        {linearTime / avxTime:.2f}x"
  
  # Verify results are similar
  var maxDiff = 0.0f32
  for i in 0..<numPhases:
    let diff = abs(linearResults[i] - avxResults[i])
    if diff > maxDiff:
      maxDiff = diff
  
  echo &"Max difference: {maxDiff:.8f}"
  echo &"Results match:  {maxDiff < 1e-6}"

when isMainModule:
  benchmark()