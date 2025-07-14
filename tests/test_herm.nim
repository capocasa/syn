import unittest
import math
import ../src/syn

suite "Hermite interpolation tests":
  
  test "AVX2 and linear versions produce same output":
    let table = @[0.0f32, 1.0f32, 0.0f32, -1.0f32, 0.0f32, 1.0f32, 0.0f32, -1.0f32, 0.0f32, 1.0f32, 0.0f32, -1.0f32]
    let phases = @[0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32]
    
    let avxResults = herm(table, phases)
    
    var linearResults = newSeq[float32](phases.len)
    for i in 0..<phases.len:
      linearResults[i] = herm(table, phases[i])
    
    check avxResults.len == linearResults.len
    
    for i in 0..<avxResults.len:
      check abs(avxResults[i] - linearResults[i]) < 1e-6
  
  test "Hermite interpolation with sine wave data":
    let tableSize = 64
    var table = newSeq[float32](tableSize + 4)
    for i in 0..<tableSize:
      table[i + 1] = sin(2.0 * PI * float32(i) / float32(tableSize))
    table[0] = table[tableSize]
    table[tableSize + 1] = table[1]
    table[tableSize + 2] = table[2]
    table[tableSize + 3] = table[3]
    
    let phases = @[0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32]
    
    let avxResults = herm(table, phases)
    
    var linearResults = newSeq[float32](phases.len)
    for i in 0..<phases.len:
      linearResults[i] = herm(table, phases[i])
    
    for i in 0..<avxResults.len:
      check abs(avxResults[i] - linearResults[i]) < 1e-6
  
  test "Edge case: zero phases":
    let table = @[8.0f32, 1.0f32, 2.0f32, 3.0f32, 4.0f32, 5.0f32, 6.0f32, 7.0f32, 8.0f32, 1.0f32, 2.0f32, 3.0f32]
    let phases = @[0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32]
    
    let avxResults = herm(table, phases)
    
    var linearResults = newSeq[float32](phases.len)
    for i in 0..<phases.len:
      linearResults[i] = herm(table, phases[i])
    
    for i in 0..<avxResults.len:
      check abs(avxResults[i] - linearResults[i]) < 1e-6