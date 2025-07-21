## Fast mathematical functions optimized for audio DSP
## Focused on real-time performance for audio-rate modulation

import std/math

# Fast tan lookup table for audio-rate filter coefficient calculations
const 
  TAN_TABLE_SIZE* = 4096  # Must be power of 2
  TAN_TABLE_RANGE* = PI / 2.0  # Cover 0 to π/2 radians
  TAN_TABLE_MASK* = TAN_TABLE_SIZE - 1  # Efficient modulo for power of 2
  TAN_SCALE_FACTOR* = float32(TAN_TABLE_SIZE - 1) / TAN_TABLE_RANGE.float32

# Power of 2 assertion for compile-time checking
template assertPo2(N: untyped) =
  assert (N and (N - 1)) == 0, "power of 2 required for N"

# Generate tan lookup table at compile time
const tanTable* = block:
  assertPo2(TAN_TABLE_SIZE)
  var table: array[TAN_TABLE_SIZE, float32]
  for i in 0..<TAN_TABLE_SIZE:
    let x = float64(i) * TAN_TABLE_RANGE / float64(TAN_TABLE_SIZE - 1)
    table[i] = tan(x).float32
  table

proc fastTan*(x: float32): float32 {.inline.} =
  ## Ultra-fast tan lookup with linear interpolation
  ## Input range: 0 to π/2 radians (assumes valid input for audio frequencies)
  ## Optimized for audio-rate filter coefficient calculation - no bounds checking
  
  # Convert to table coordinates using pre-computed scale factor
  let tablePos = x * TAN_SCALE_FACTOR
  let index = int(tablePos)
  let fraction = tablePos - float32(index)
  
  # Branchless linear interpolation with mask for wraparound
  let y0 = tanTable[index and TAN_TABLE_MASK]
  let y1 = tanTable[(index + 1) and TAN_TABLE_MASK]
  
  result = y0 + fraction * (y1 - y0)

# Fast pow10 lookup table for dB conversions (pow(10, x/40))
const 
  POW10_TABLE_SIZE* = 2048  # Must be power of 2
  POW10_MIN_DB* = -60.0  # Cover -60dB to +60dB
  POW10_MAX_DB* = 60.0
  POW10_RANGE* = POW10_MAX_DB - POW10_MIN_DB
  POW10_TABLE_MASK* = POW10_TABLE_SIZE - 1
  POW10_SCALE_FACTOR* = float32(POW10_TABLE_SIZE - 1) / POW10_RANGE.float32

# Generate pow10 lookup table at compile time for dB conversions
const pow10Table* = block:
  assertPo2(POW10_TABLE_SIZE)
  var table: array[POW10_TABLE_SIZE, float32]
  for i in 0..<POW10_TABLE_SIZE:
    let dbValue = POW10_MIN_DB + float64(i) * POW10_RANGE / float64(POW10_TABLE_SIZE - 1)
    table[i] = pow(10.0, dbValue / 40.0).float32  # For EQ gain calculations
  table

proc fastPow10*(dbGain: float64): float32 {.inline.} =
  ## Ultra-fast pow(10, dbGain/40) lookup for dB to linear conversion
  ## Input range: -60dB to +60dB (typical audio range)
  ## Optimized for audio EQ calculations
  
  # Clamp to table range
  let clampedDb = max(POW10_MIN_DB, min(POW10_MAX_DB, dbGain))
  
  # Convert to table coordinates
  let tablePos = (clampedDb - POW10_MIN_DB) * POW10_SCALE_FACTOR.float64
  let index = int(tablePos)
  let fraction = float32(tablePos - float64(index))
  
  # Branchless linear interpolation
  let y0 = pow10Table[index and POW10_TABLE_MASK]
  let y1 = pow10Table[(index + 1) and POW10_TABLE_MASK]
  
  result = y0 + fraction * (y1 - y0)