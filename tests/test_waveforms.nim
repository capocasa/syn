import unittest
import math
import ../src/syn

suite "Bandlimited wavetables":
  test "fillSaw generates valid wavetable":
    var table: array[1024, float32]
    fillSaw(table, 48000.0f32)
    
    # Check table is not all zeros
    var hasNonZero = false
    for val in table:
      if val != 0.0f32:
        hasNonZero = true
        break
    check hasNonZero
    
    # Check values are in reasonable range [-1, 1]
    for val in table:
      check val >= -1.0f32 and val <= 1.0f32
    
    # Check first and last values match expected bandlimited values
    check almostEqual(table[0], -1.0f32, 1)
    check almostEqual(table[^1], 0.9980468f32, 1)
  
  test "fillSawd generates valid wavetable":
    var table: array[1024, float32]
    fillSawd(table, 48000.0f32)
    
    # Check table is not all zeros
    var hasNonZero = false
    for val in table:
      if val != 0.0f32:
        hasNonZero = true
        break
    check hasNonZero
    
    # Check values are in reasonable range [-1, 1]
    for val in table:
      check val >= -1.0f32 and val <= 1.0f32
    
    # Check first and last values match expected bandlimited values
    check almostEqual(table[0], 1.0f32, 1)
    check almostEqual(table[^1], -0.9980468f32, 1)
  
  test "fillSaw convenience function":
    let table = fillSaw[512](48000.0f32)
    
    # Check table is not all zeros
    var hasNonZero = false
    for val in table:
      if val != 0.0f32:
        hasNonZero = true
        break
    check hasNonZero
    
    # Check values are in reasonable range
    for val in table:
      check val >= -1.0f32 and val <= 1.0f32
  
  test "fillSawd convenience function":
    let table = fillSawd[512](48000.0f32)
    
    # Check table is not all zeros
    var hasNonZero = false
    for val in table:
      if val != 0.0f32:
        hasNonZero = true
        break
    check hasNonZero
    
    # Check values are in reasonable range
    for val in table:
      check val >= -1.0f32 and val <= 1.0f32

  
