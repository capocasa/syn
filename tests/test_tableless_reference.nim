import unittest
import math
import ../src/syn

# Slow but obviously correct reference implementations
proc referenceSaw(phase: uint): float32 =
  # Convert phase to 0..1 range, then to -1..1 sawtooth
  let normalized = phase.float64 / (high(uint).float64 + 1.0)
  float32(normalized * 2.0 - 1.0)

proc referenceSawd(phase: uint): float32 =
  # Downward sawtooth: starts at 1, goes to -1
  let normalized = phase.float64 / (high(uint).float64 + 1.0)
  float32(1.0 - normalized * 2.0)

proc referencePulse(phase: uint, width: float32): float32 =
  # Square wave based on phase position vs width threshold
  let normalized = phase.float64 / (high(uint).float64 + 1.0)
  if normalized < width.float64:
    -1.0f
  else:
    1.0f

suite "Tableless oscillator (reference-based tests)":
  test "saw basic values":
    check saw(0'u) == referenceSaw(0'u)
    check saw(high(uint)) == referenceSaw(high(uint))
    check saw(high(uint) shr 1) == referenceSaw(high(uint) shr 1)
    check saw(high(uint) shr 2) == referenceSaw(high(uint) shr 2)
    check saw(high(uint) - (high(uint) shr 2)) == referenceSaw(high(uint) - (high(uint) shr 2))

  test "saw specific values":
    # Test meaningful phase values that are distributed across the full range
    let testPhases = [
      high(uint) div 8,     # 1/8 of full range
      high(uint) div 4,     # 1/4 of full range  
      high(uint) div 2,     # 1/2 of full range
      high(uint) * 3 div 4, # 3/4 of full range
      high(uint) * 7 div 8  # 7/8 of full range
    ]
    
    for phase in testPhases:
      check almostEqual(saw(phase), referenceSaw(phase), 1)

  test "saw monotonic":
    let samples = [0'u, high(uint) shr 3, high(uint) shr 2, high(uint) shr 1, 
                   high(uint) - (high(uint) shr 2), high(uint)]
    for i in 0..<samples.high:
      check saw(samples[i]) < saw(samples[i+1])

  test "sawd basic values":
    check sawd(0'u) == referenceSawd(0'u)
    check sawd(high(uint)) == referenceSawd(high(uint))
    check sawd(high(uint) shr 1) == referenceSawd(high(uint) shr 1)
    
  test "sawd specific values":
    let testPhases = [
      high(uint) div 8,     # 1/8 of full range
      high(uint) div 4,     # 1/4 of full range  
      high(uint) div 2,     # 1/2 of full range
      high(uint) * 3 div 4, # 3/4 of full range
      high(uint) * 7 div 8  # 7/8 of full range
    ]
    
    for phase in testPhases:
      check almostEqual(sawd(phase), referenceSawd(phase), 1)

  test "saw + sawd = 0 relationship":
    let testPhases = [0'u, high(uint) shr 2, high(uint) shr 1, high(uint)]
    for phase in testPhases:
      check almostEqual(saw(phase) + sawd(phase), 0'f, 1)

  test "pulse basic values":
    check pulse(0'u, 0.5'f) == referencePulse(0'u, 0.5'f)
    check pulse(high(uint), 0.5'f) == referencePulse(high(uint), 0.5'f)
    check pulse(high(uint) shr 1, 0.5'f) == referencePulse(high(uint) shr 1, 0.5'f)
    check pulse(0'u, 0.25'f) == referencePulse(0'u, 0.25'f)
    check pulse(high(uint) shr 2, 0.25'f) == referencePulse(high(uint) shr 2, 0.25'f)
    check pulse(high(uint) shr 1, 0.25'f) == referencePulse(high(uint) shr 1, 0.25'f)

  test "pulse duty cycle validation":
    # Test pulse with different duty cycles at various phase positions
    let testPhases = [
      0'u,
      high(uint) div 8,
      high(uint) div 4,
      high(uint) div 2,
      high(uint) * 3 div 4,
      high(uint) * 7 div 8,
      high(uint)
    ]
    
    let widths = [0.25'f, 0.5'f, 0.75'f]
    
    for width in widths:
      for phase in testPhases:
        check pulse(phase, width) == referencePulse(phase, width)