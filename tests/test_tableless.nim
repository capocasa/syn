import unittest
import math
import ../src/syn

suite "Tableless oscillator":
 test "saw":
   check saw(0'u) == -1'f
   check saw(high(uint)) == 1.0'f
   check saw(high(uint) shr 1) == 0'f  # midpoint
   check saw(high(uint) shr 2) == -0.5'f  # quarter
   check saw(high(uint) - (high(uint) shr 2)) == 0.5'f  # three quarters
   # Proper 64-bit equivalents of original 32-bit test values
   check almostEqual(saw(0x2A3F5B122A3F5B12'u), -0.66994154'f, 1)  # first quarter
   check almostEqual(saw(0x5E8A1C7D5E8A1C7D'u), -0.26141018'f, 1)  # second quarter  
   check almostEqual(saw(0x9B4D2F819B4D2F81'u), 0.21329302'f, 1)   # third quarter
   check almostEqual(saw(0xD8F1A429D8F1A429'u), 0.6948743'f, 1)    # fourth quarter
   
 test "saw monotonic":
   let samples = [0'u, high(uint) shr 3, high(uint) shr 2, high(uint) shr 1, 
                  high(uint) - (high(uint) shr 2), high(uint)]
   for i in 0..<samples.high:
     check saw(samples[i]) < saw(samples[i+1])
     
 test "sawd":
   check sawd(0'u) == 1'f
   check sawd(high(uint)) == -1.0'f
   check sawd(high(uint) shr 1) == 0'f
   # Proper 64-bit equivalents of original 32-bit test values
   check almostEqual(sawd(0x1C4A8F231C4A8F23'u), 0.77897465'f, 1)  # first quarter
   check almostEqual(sawd(0x6F2B5A916F2B5A91'u), 0.13148944'f, 1)  # second quarter
   check almostEqual(sawd(0xA8E1D4C7A8E1D4C7'u), -0.31939182'f, 1) # third quarter
   check almostEqual(sawd(0xE5B2F18AE5B2F18A'u), -0.7945234'f, 1) # fourth quarter
   for phase in [0'u, high(uint) shr 2, high(uint) shr 1, high(uint)]:
     check almostEqual(saw(phase) + sawd(phase), 0'f, 1)
     
 test "pulse duty cycle":
   check pulse(0'u, 0.5'f) == -1'f
   check pulse(high(uint), 0.5'f) == 1'f
   check pulse(high(uint) shr 1, 0.5'f) == 1'f  # just past midpoint
   check pulse(0'u, 0.25'f) == -1'f
   check pulse(high(uint) shr 2, 0.25'f) == 1'f  # quarter point
   check pulse(high(uint) shr 1, 0.25'f) == 1'f  # half point
   # Proper 64-bit equivalents of original 32-bit test values
   check pulse(0x3D9E7B453D9E7B45'u, 0.5'f) == -1'f  # first quarter (0.24)
   check pulse(0x7A1F2C687A1F2C68'u, 0.5'f) == -1'f  # second quarter (0.48)
   check pulse(0xB6C4E892B6C4E892'u, 0.5'f) == 1'f   # third quarter (0.71)
   check pulse(0xF2A9D1B7F2A9D1B7'u, 0.5'f) == 1'f   # fourth quarter (0.95)
