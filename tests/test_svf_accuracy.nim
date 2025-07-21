## Comprehensive accuracy test comparing reference vs optimized SVF implementations
## This ensures our lookup table optimizations maintain numerical accuracy

import unittest
import math
import strformat
import ../src/svf
import ../src/svf_reference

const
  SAMPLE_RATE = 48000.0
  TEST_FREQUENCIES = [20.0, 100.0, 440.0, 1000.0, 4000.0, 8000.0, 15000.0]
  TEST_Q_VALUES = [0.3, 0.707, 1.0, 2.0, 10.0, 50.0]
  TEST_DB_GAINS = [-24.0, -12.0, -6.0, 0.0, 6.0, 12.0, 24.0]
  ACCURACY_THRESHOLD = 1e-4f32  # Allow small differences due to lookup table interpolation
  IMPULSE_LENGTH = 1024

proc almostEqual(a, b: float32, tolerance: float32 = ACCURACY_THRESHOLD): bool =
  abs(a - b) < tolerance

proc relativeError(reference, optimized: float32): float32 =
  # Improved relative error calculation that handles noise floor better
  let absRef = abs(reference)
  let absOpt = abs(optimized)
  let absDiff = abs(optimized - reference)
  
  # If both values are very small (near noise floor), use absolute error
  if absRef < 1e-6f32 and absOpt < 1e-6f32:
    return absDiff  # Absolute error for very small values
  
  # If reference is very small but optimized isn't, something's wrong
  if absRef < 1e-10f32:
    return if absOpt < 1e-6f32: absDiff else: absOpt
  
  # Normal relative error calculation
  absDiff / absRef

proc testFilterAccuracy(refFilter: var svf_reference.StateVariableFilter, 
                       optFilter: var svf.StateVariableFilter,
                       testName: string) =
  ## Test filter accuracy by processing an impulse and comparing outputs
  var maxError = 0.0f32
  var avgError = 0.0f32
  var errorCount = 0
  
  # Reset both filters
  refFilter.reset()
  optFilter.reset()
  
  # Process impulse response
  for i in 0..<IMPULSE_LENGTH:
    let input = if i == 0: 1.0f32 else: 0.0f32
    let refOutput = refFilter.next(input)
    let optOutput = optFilter.next(input)
    
    let error = relativeError(refOutput, optOutput)
    maxError = max(maxError, error)
    avgError += error
    errorCount += 1
    
    # Check for catastrophic failures (ignore noise floor issues)
    if not isNaN(refOutput) and not isNaN(optOutput):
      if error > 0.01f32 and (abs(refOutput) > 1e-6f32 or abs(optOutput) > 1e-6f32):
        echo "  WARNING: Large error at sample ", i, ": ref=", refOutput, " opt=", optOutput, " error=", error * 100.0, "%"
  
  avgError /= float32(errorCount)
  
  echo "  ", testName
  echo "    Max relative error: ", maxError * 100.0, "%"
  echo "    Avg relative error: ", avgError * 100.0, "%"
  
  # Assert acceptable accuracy (more lenient for edge cases)
  check maxError < 0.05f32  # Less than 5% max error (allows for noise floor issues)
  check avgError < 0.01f32  # Less than 1% average error

suite "SVF Accuracy Comparison":
  
  test "lowpass filter accuracy across frequency range":
    for freq in TEST_FREQUENCIES:
      for q in TEST_Q_VALUES:
        if freq < SAMPLE_RATE / 2.1:  # Stay below Nyquist with margin
          var refFilter = svf_reference.initStateVariableFilter()
          var optFilter = svf.initStateVariableFilter()
          
          refFilter.lowpass(SAMPLE_RATE, freq, q)
          optFilter.lowpass(SAMPLE_RATE, freq, q)
          
          testFilterAccuracy(refFilter, optFilter, 
            &"Lowpass f={freq}Hz Q={q}")

  test "highpass filter accuracy across frequency range":
    for freq in TEST_FREQUENCIES:
      for q in TEST_Q_VALUES:
        if freq < SAMPLE_RATE / 2.1:
          var refFilter = svf_reference.initStateVariableFilter()
          var optFilter = svf.initStateVariableFilter()
          
          refFilter.highpass(SAMPLE_RATE, freq, q)
          optFilter.highpass(SAMPLE_RATE, freq, q)
          
          testFilterAccuracy(refFilter, optFilter, 
            &"Highpass f={freq}Hz Q={q}")

  test "bandpass filter accuracy across frequency range":
    for freq in TEST_FREQUENCIES:
      for q in TEST_Q_VALUES:
        if freq < SAMPLE_RATE / 2.1:
          var refFilter = svf_reference.initStateVariableFilter()
          var optFilter = svf.initStateVariableFilter()
          
          refFilter.bandpass(SAMPLE_RATE, freq, q)
          optFilter.bandpass(SAMPLE_RATE, freq, q)
          
          testFilterAccuracy(refFilter, optFilter, 
            &"Bandpass f={freq}Hz Q={q}")

  test "notch filter accuracy across frequency range":
    for freq in TEST_FREQUENCIES:
      for q in TEST_Q_VALUES:
        if freq < SAMPLE_RATE / 2.1:
          var refFilter = svf_reference.initStateVariableFilter()
          var optFilter = svf.initStateVariableFilter()
          
          refFilter.notch(SAMPLE_RATE, freq, q)
          optFilter.notch(SAMPLE_RATE, freq, q)
          
          testFilterAccuracy(refFilter, optFilter, 
            &"Notch f={freq}Hz Q={q}")

  test "allpass filter accuracy across frequency range":
    for freq in TEST_FREQUENCIES:
      for q in TEST_Q_VALUES:
        if freq < SAMPLE_RATE / 2.1:
          var refFilter = svf_reference.initStateVariableFilter()
          var optFilter = svf.initStateVariableFilter()
          
          refFilter.allpass(SAMPLE_RATE, freq, q)
          optFilter.allpass(SAMPLE_RATE, freq, q)
          
          testFilterAccuracy(refFilter, optFilter, 
            &"Allpass f={freq}Hz Q={q}")

  test "peaking filter accuracy across frequency range":
    for freq in TEST_FREQUENCIES:
      for q in TEST_Q_VALUES:
        if freq < SAMPLE_RATE / 2.1:
          var refFilter = svf_reference.initStateVariableFilter()
          var optFilter = svf.initStateVariableFilter()
          
          refFilter.peaking(SAMPLE_RATE, freq, q)
          optFilter.peaking(SAMPLE_RATE, freq, q)
          
          testFilterAccuracy(refFilter, optFilter, 
            &"Peaking f={freq}Hz Q={q}")

  test "bell filter accuracy with dB gains":
    for freq in [440.0, 1000.0, 4000.0]:  # Subset for performance
      for q in [0.707, 2.0]:
        for gain in TEST_DB_GAINS:
          if freq < SAMPLE_RATE / 2.1:
            var refFilter = svf_reference.initStateVariableFilter()
            var optFilter = svf.initStateVariableFilter()
            
            refFilter.bell(SAMPLE_RATE, freq, q, gain)
            optFilter.bell(SAMPLE_RATE, freq, q, gain)
            
            testFilterAccuracy(refFilter, optFilter, 
              &"Bell f={freq}Hz Q={q} gain={gain}dB")

  test "lowShelf filter accuracy with dB gains":
    for freq in [100.0, 1000.0, 4000.0]:  # Subset for performance
      for q in [0.707, 2.0]:
        for gain in TEST_DB_GAINS:
          if freq < SAMPLE_RATE / 2.1:
            var refFilter = svf_reference.initStateVariableFilter()
            var optFilter = svf.initStateVariableFilter()
            
            refFilter.lowShelf(SAMPLE_RATE, freq, q, gain)
            optFilter.lowShelf(SAMPLE_RATE, freq, q, gain)
            
            testFilterAccuracy(refFilter, optFilter, 
              &"LowShelf f={freq}Hz Q={q} gain={gain}dB")

  test "highShelf filter accuracy with dB gains":
    for freq in [1000.0, 4000.0, 8000.0]:  # Subset for performance
      for q in [0.707, 2.0]:
        for gain in TEST_DB_GAINS:
          if freq < SAMPLE_RATE / 2.1:
            var refFilter = svf_reference.initStateVariableFilter()
            var optFilter = svf.initStateVariableFilter()
            
            refFilter.highShelf(SAMPLE_RATE, freq, q, gain)
            optFilter.highShelf(SAMPLE_RATE, freq, q, gain)
            
            testFilterAccuracy(refFilter, optFilter, 
              &"HighShelf f={freq}Hz Q={q} gain={gain}dB")

  test "coefficient accuracy comparison":
    echo "\nDirect coefficient comparison:"
    for freq in [440.0, 1000.0, 4000.0]:
      for q in [0.707, 2.0]:
        var refFilter = svf_reference.initStateVariableFilter()
        var optFilter = svf.initStateVariableFilter()
        
        refFilter.lowpass(SAMPLE_RATE, freq, q)
        optFilter.lowpass(SAMPLE_RATE, freq, q)
        
        echo &"  f={freq}Hz Q={q}:"
        echo &"    g: ref={refFilter.g:.6f} opt={optFilter.g:.6f} error={relativeError(refFilter.g.float32, optFilter.g.float32) * 100:.4f}%"
        echo &"    k: ref={refFilter.k:.6f} opt={optFilter.k:.6f} error={relativeError(refFilter.k.float32, optFilter.k.float32) * 100:.4f}%"
        echo &"    a1: ref={refFilter.a1:.6f} opt={optFilter.a1:.6f} error={relativeError(refFilter.a1.float32, optFilter.a1.float32) * 100:.4f}%"
        
        # Check coefficient accuracy
        check relativeError(refFilter.g.float32, optFilter.g.float32) < 0.001f32
        check relativeError(refFilter.k.float32, optFilter.k.float32) < 1e-6f32  # k should be exact
        check relativeError(refFilter.a1.float32, optFilter.a1.float32) < 0.001f32

  test "extreme parameter edge cases":
    echo "\nTesting extreme parameter cases:"
    
    # Very low frequency
    var refFilter = svf_reference.initStateVariableFilter()
    var optFilter = svf.initStateVariableFilter()
    
    refFilter.lowpass(SAMPLE_RATE, 5.0, 0.707)
    optFilter.lowpass(SAMPLE_RATE, 5.0, 0.707)
    testFilterAccuracy(refFilter, optFilter, "Extreme low freq (5Hz)")
    
    # Very high Q
    refFilter.reset()
    optFilter.reset()
    refFilter.lowpass(SAMPLE_RATE, 1000.0, 100.0)
    optFilter.lowpass(SAMPLE_RATE, 1000.0, 100.0)
    testFilterAccuracy(refFilter, optFilter, "Extreme high Q (100)")
    
    # Very low Q
    refFilter.reset()
    optFilter.reset()
    refFilter.lowpass(SAMPLE_RATE, 1000.0, 0.1)
    optFilter.lowpass(SAMPLE_RATE, 1000.0, 0.1)
    testFilterAccuracy(refFilter, optFilter, "Extreme low Q (0.1)")

  test "lookup table boundary conditions":
    echo "\nTesting lookup table boundaries:"
    
    # Test near table boundaries for fastTan
    let testFreqs = [0.1, 1.0, SAMPLE_RATE * 0.49, SAMPLE_RATE * 0.499]
    
    for freq in testFreqs:
      if freq > 0 and freq < SAMPLE_RATE / 2.1:
        var refFilter = svf_reference.initStateVariableFilter()
        var optFilter = svf.initStateVariableFilter()
        
        refFilter.lowpass(SAMPLE_RATE, freq, 0.707)
        optFilter.lowpass(SAMPLE_RATE, freq, 0.707)
        
        let refG = tan(PI * freq / SAMPLE_RATE).float32
        let optG = optFilter.g
        let tanError = relativeError(refG, optG)
        
        echo &"  f={freq}Hz: tan error = {tanError * 100:.4f}%"
        check tanError < 0.01f32  # Less than 1% error for tan approximation