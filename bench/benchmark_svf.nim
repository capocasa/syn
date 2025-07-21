import std/[times, math, random, strformat]
import src/svf

const
  SAMPLE_RATE = 48000.0
  BUFFER_SIZE = 512
  NUM_ITERATIONS = 50000  # About 26 seconds of audio at 48kHz with 512 sample buffers
  MIN_FREQ = 20.0
  MAX_FREQ = 8000.0
  TOTAL_SAMPLES = NUM_ITERATIONS * BUFFER_SIZE

# Pre-calculate frequency values for each iteration (not every sample)
const FREQ_TABLE_SIZE = NUM_ITERATIONS
const frequencyTable = block:
  var table: array[FREQ_TABLE_SIZE, float64]
  for i in 0..<FREQ_TABLE_SIZE:
    let phase = float64(i) / float64(FREQ_TABLE_SIZE)
    table[i] = MIN_FREQ * pow(MAX_FREQ / MIN_FREQ, phase)
  table

proc benchmarkSweepableFilter() =
  var filter = initStateVariableFilter()
  var input: array[BUFFER_SIZE, float32]
  var output: array[BUFFER_SIZE, float32]
  
  # Initialize with noise
  var rng = initRand(12345)
  for i in 0..<BUFFER_SIZE:
    input[i] = rng.gauss(0.0, 0.1).float32
  
  echo "Benchmarking SVF with audio-rate frequency sweeping..."
  echo fmt"Sample rate: {SAMPLE_RATE} Hz"
  echo fmt"Buffer size: {BUFFER_SIZE} samples"
  echo fmt"Total iterations: {NUM_ITERATIONS}"
  echo fmt"Frequency range: {MIN_FREQ} Hz - {MAX_FREQ} Hz"
  echo ""
  
  let startTime = cpuTime()
  
  for iteration in 0..<NUM_ITERATIONS:
    # Use pre-calculated frequency for this iteration - eliminates pow() calls
    let baseFreq = frequencyTable[iteration]
    
    # Process buffer with frequency sweep
    for sample in 0..<BUFFER_SIZE:
      # Calculate sample-level frequency variation
      let samplePhase = float64(sample) / float64(BUFFER_SIZE) / float64(NUM_ITERATIONS)
      let currentFreq = baseFreq * (1.0 + samplePhase * 0.01) # Small variation within buffer
      
      # This is the critical path - coefficient calculation
      filter.lowpass(SAMPLE_RATE, currentFreq, 0.707)
      
      # Process sample
      output[sample] = filter.next(input[sample])
  
  let endTime = cpuTime()
  let duration = endTime - startTime
  
  let totalSamples = NUM_ITERATIONS * BUFFER_SIZE
  let realTimeRatio = (float64(totalSamples) / SAMPLE_RATE) / duration
  
  echo fmt"Benchmark completed in {duration:.3f} seconds"
  echo fmt"Processed {totalSamples} samples"
  echo fmt"Performance: {realTimeRatio:.2f}x real-time"
  echo fmt"Samples per second: {float64(totalSamples) / duration:.0f}"
  echo fmt"Coefficient calculations per second: {float64(totalSamples) / duration:.0f}"
  
  if realTimeRatio < 1.0:
    echo "WARNING: Not achieving real-time performance!"
  else:
    echo "SUCCESS: Achieving real-time performance"

when isMainModule:
  benchmarkSweepableFilter()
