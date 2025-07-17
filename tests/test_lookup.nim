import unittest
import math
import ../src/syn

suite "Table lookups":
  
  let waveform = [
    0.0'f32,
    0.5'f32,
    1.0'f32,
    0.5'f32,
    0.0'f32,
    -0.5'f32,
    -1.0'f32,
    -0.5'f32
  ]
  
  test "Nearest neighbor":
    check waveform.near(0'u) == 0.0
    check waveform.near(high(uint) div 2) == 0.5
    check waveform.near(high(uint) div 2 + 1) == 0.0
    check waveform.near(high(uint) - high(uint) div 4 - 1) == -0.5
    check waveform.near(high(uint) - high(uint) div 4) == -1.0
    check waveform.near(high(uint) - high(uint) div 9) == -0.5
    check waveform.near(high(uint)) == -0.5
    check waveform.near(high(uint) + 1) == -0.0  # same as 0'u, this is just for the skeptics

  test "Linear interpolation":
    check waveform.lin(0'u) == 0.0
    check waveform.lin(high(uint) div 2) == 0.0  # no edge case like nearest neighbor
    check waveform.lin(high(uint) div 2 + 1) == 0.0
    check waveform.lin(high(uint) - high(uint) div 4 - 1) == -1.0 # no edge case
    check waveform.lin(high(uint) - high(uint) div 4) == -1.0
    check almostEqual(waveform.lin(high(uint) - high(uint) div 9), -0.44444445, 1)
    check almostEqual(waveform.lin(high(uint) - high(uint) div 9), -0.44444445, 1)
    check waveform.lin(high(uint)) == -0.0 # no edge case
    check waveform.lin(high(uint) + 1) == -0.0
    
    check almostEqual(waveform.lin(high(uint) - high(uint) div 7), -0.5714286)
  
  test "Hermite interpolation":
    check waveform.herm(0'u) == 0.0
    check waveform.herm(high(uint) div 2) == 0.0  # no edge case like nearest neighbor
    check waveform.herm(high(uint) div 2 + 1) == 0.0
    check waveform.herm(high(uint) - high(uint) div 4 - 1) == -1.0 # no edge case
    check waveform.herm(high(uint) - high(uint) div 4) == -1.0
    check almostEqual(waveform.herm(high(uint) - high(uint) div 9), -0.44444445, 1)
    check almostEqual(waveform.herm(high(uint) - high(uint) div 9), -0.44444445, 1)
    check waveform.herm(high(uint)) == -0.0 # no edge case
    check waveform.herm(high(uint) + 1) == -0.0
    
    check almostEqual(waveform.herm(high(uint) - high(uint) div 7), -0.5801749)

    # TODO: I have no idea what hermite is supposed to look like, so a few
    # more key tests would be good

