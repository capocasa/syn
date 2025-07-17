import unittest
import math
import ../src/syn

suite "Phase accumulator tests":
  
  test "Simple index and interpolation-fraction examples for an 8 sample table":
    var phase = 0'u64
    check index(8, phase) == 0'u
    check fraction(8, phase) == 0.0

    check index(8, phase) == 0'u
    check fraction(8, phase) == 0.0

    phase = high(uint) div 8
    check index(8, phase) == 0'u
    check fraction(8, phase) == 1.0  # almost but not quite 1 but good enough for check
    
    phase = high(uint) div 4 + 1
    check index(8, phase) == 2'u
    check fraction(8, phase) == 0.0

    phase = high(uint) div 8 + 1
    check index(8, phase) == 1'u
    check fraction(8, phase) == 0.0
    
    phase = high(uint) div 6
    check index(8, phase) == 1'u
    check fraction(8, phase) == 0.3333333333333333

    phase = high(uint) div 5
    check index(8, phase) == 1'u
    check fraction(8, phase) == 0.6
    
    phase = high(uint) div 3
    check index(8, phase) == 2'u
    check fraction(8, phase) == 0.6666666666666666

    phase = high(uint) div 2
    check index(8, phase) == 3'u
    check fraction(8, phase) == 1.0
    
    phase = high(uint) div 2 + 1
    check index(8, phase) == 4'u
    check fraction(8, phase) == 0.0
    
    phase = high(uint) - high(uint) div 3
    check index(8, phase) == 5'u
    check fraction(8, phase) == 0.3333333333333333

    phase = high(uint)
    check index(8, phase) == 7'u
    check fraction(8, phase) == 1.0


