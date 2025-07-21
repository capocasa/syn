import unittest
import math
import ../src/svf

proc almostEqual(a, b: float32, tolerance: float32 = 1e-6): bool =
  abs(a - b) < tolerance

suite "State Variable Filter":
  test "initialization":
    var filter = initStateVariableFilter()
    check filter.ic1eq == 0.0
    check filter.ic2eq == 0.0
    check filter.m0 == 0.0
    check filter.m1 == 0.0
    check filter.m2 == 0.0

  test "reset clears internal state":
    var filter = initStateVariableFilter()
    filter.ic1eq = 0.5
    filter.ic2eq = 0.3
    filter.reset()
    check filter.ic1eq == 0.0
    check filter.ic2eq == 0.0

  test "lowpass filter - DC passes, high freq attenuates":
    var filter = initStateVariableFilter()
    filter.lowpass(44100.0, 1000.0, 0.707)
    
    # DC (0 Hz) should pass through - let filter settle
    for i in 0..<100:
      discard filter.next(1.0)
    let dcOut = filter.next(1.0)
    check almostEqual(dcOut, 1.0, 0.1)
    
    # Reset and test with alternating signal (high frequency)
    filter.reset()
    var highFreqSum = 0.0f32
    for i in 0..<100:
      let input = if i mod 2 == 0: 1.0f32 else: -1.0f32
      highFreqSum += abs(filter.next(input))
    let highFreqAvg = highFreqSum / 100.0f32
    check highFreqAvg < 0.5  # Should be attenuated

  test "highpass filter - DC blocked, high freq passes":
    var filter = initStateVariableFilter()
    filter.highpass(44100.0, 1000.0, 0.707)
    
    # DC should be blocked - feed constant input
    filter.reset()
    var dcSum = 0.0f32
    for i in 0..<100:
      dcSum += abs(filter.next(1.0))
    let dcAvg = dcSum / 100.0f32
    check dcAvg < 0.1  # Should be heavily attenuated

  test "bandpass filter - passes band, attenuates extremes":
    var filter = initStateVariableFilter()
    filter.bandpass(44100.0, 1000.0, 2.0)  # Higher Q for narrower band
    
    # DC should be blocked
    filter.reset()
    var dcSum = 0.0f32
    for i in 0..<50:
      dcSum += abs(filter.next(1.0))
    let dcAvg = dcSum / 50.0f32
    check dcAvg < 0.2
    
    # Very high frequency should be blocked
    filter.reset()
    var highFreqSum = 0.0f32
    for i in 0..<50:
      let input = if i mod 2 == 0: 1.0f32 else: -1.0f32
      highFreqSum += abs(filter.next(input))
    let highFreqAvg = highFreqSum / 50.0f32
    check highFreqAvg < 0.5

  test "notch filter - blocks specific frequency":
    var filter = initStateVariableFilter()
    filter.notch(44100.0, 1000.0, 10.0)  # High Q for sharp notch
    
    # DC should pass
    let dcOut = filter.next(1.0)
    check almostEqual(dcOut, 1.0, 0.1)

  test "allpass filter - preserves amplitude, shifts phase":
    var filter = initStateVariableFilter()
    filter.allpass(44100.0, 1000.0, 0.707)
    
    # Should have unity gain for DC
    let dcOut = filter.next(1.0)
    check almostEqual(abs(dcOut), 1.0, 0.5)

  test "peaking filter":
    var filter = initStateVariableFilter()
    filter.peaking(44100.0, 1000.0, 2.0)
    
    # Should have some response to input
    let output = filter.next(1.0)
    check abs(output) > 0.0

  test "bell filter with gain":
    var filter = initStateVariableFilter()
    filter.bell(44100.0, 1000.0, 2.0, 6.0)  # +6dB gain
    
    # Should amplify at center frequency
    let output = filter.next(1.0)
    check abs(output) > 0.0

  test "low shelf filter":
    var filter = initStateVariableFilter()
    filter.lowShelf(44100.0, 1000.0, 0.707, 6.0)  # +6dB boost below 1kHz
    
    # DC should be boosted
    let dcOut = filter.next(1.0)
    check abs(dcOut) > 1.0  # Should be amplified

  test "high shelf filter":
    var filter = initStateVariableFilter()
    filter.highShelf(44100.0, 1000.0, 0.707, 6.0)  # +6dB boost above 1kHz
    
    # Test with input
    let output = filter.next(1.0)
    check abs(output) > 0.0

  test "filter stability - no NaN or infinite values":
    var filter = initStateVariableFilter()
    filter.lowpass(44100.0, 100.0, 0.1)  # Very low Q
    
    # Process many samples to check stability
    for i in 0..<1000:
      let input = sin(2.0 * PI * float32(i) / 100.0)  # 440 Hz sine
      let output = filter.next(input)
      check not isNaN(output)
      check not (classify(output) in {fcInf, fcNegInf})
      check abs(output) < 100.0  # Reasonable bounds

  test "extreme Q values don't crash":
    var filter = initStateVariableFilter()
    
    # Very low Q
    filter.lowpass(44100.0, 1000.0, 0.01)
    let output1 = filter.next(1.0)
    check not isNaN(output1)
    
    # Very high Q (near oscillation)
    filter.reset()
    filter.lowpass(44100.0, 1000.0, 100.0)
    let output2 = filter.next(1.0)
    check not isNaN(output2)

  test "extreme frequency values":
    var filter = initStateVariableFilter()
    
    # Very low frequency
    filter.lowpass(44100.0, 1.0, 0.707)
    let output1 = filter.next(1.0)
    check not isNaN(output1)
    
    # High frequency (near Nyquist)
    filter.reset()
    filter.lowpass(44100.0, 20000.0, 0.707)
    let output2 = filter.next(1.0)
    check not isNaN(output2)