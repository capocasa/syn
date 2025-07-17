import std/[math, bitops]
#import nimsimd/avx2, pffft

# some templates to derive some values at compile time
# these would be constants if the table length was fixed

template indexBitCount*(N: int): int =
  # the most significant N bits of the int are used to index into the wavetables
  # an unsigned int phase wraps around naturally which is worth it since this stuff
  # get's called at every sample, 48k times per second or more
  N.countTrailingZeroBits

template indexHigh*(N: int): uint =
  # This is the highest number that can be represented by the bits reserved
  # for the index. This can be used with a bitwise and to efficiently wrap
  uint(N) - 1

template fractionBitCount*(N: int): int =
  # the remaining bits of the int are used to create a float 0..1 and used for interpolation
  # you take this many bits from the phase, and divite by the max value represented by those bits
  # they are simply the bits that are left over after subtracting the ones from the table size
  # 
  # the value is totally massively overkill but allows phase stability even after days and weeks
  # and costs nothing on 64 bit systems. also, if you have really large wavetables, say 16 bits,
  # it's still more than enough for nice interpolation
  sizeof(int) * 8 - indexBitCount(N)

template fractionHigh*(N: int): uint =
  # the highest number that can be represented with the number of bits in the phase value that
  # are reserved for interpolation
  1'u64 shl fractionBitCount(N) - 1

template assertPo2*(N: untyped) =
  # insist certain values be a power of 2
  assert (N and (N - 1)) == 0, "power of 2 required for N"

template inverseFractionHigh*(N): float =
  # this is mostly here to make it clear we are dividing
  # by a constant value, which is done as a (fast) multiplication
  
  # converting loses a bit but fractionBitCount is more like 52 bits anyway,
  # depending on wavetable size
  1 / fractionHigh(N).float

template index*(N: int, phase: uint): uint =
  # Get the wavetable index from the phase
  # It will just shift off the bits representing the fraction-of-a-sample
  # 
  # the remaing ones can directly index the table
  # this is very efficient and they way digital synths have been done for ages
  # including the Yamaha DX7 and even further back
  #
  # The int is just there as a reminder that table sizes don't get that large,
  # the compiler probably turns it into int anyway for performance
  #
  # Learned this trick from studying the Helm-Synth oscillator. It's a testament to
  # the power of Free Software that I was allowed to observe such extreme skill.
  #
  # Thanks Matt!
  phase shr fractionBitCount(N)  # note shr pads zeros (logical right shift) for unsigned integers, which is what we want

template fraction*(N: int, phase: uint): float =
  # Mask the index bits, multiply by inverse-of-max to get the fraction as
  # a float for further processing
  float(phase and fractionHigh(N)) * inverseFractionHigh(N)

template indexFraction*(N: int, phase: uint): (uint, float) =
  (index(N, phase), fraction(N, phase))

proc near*[N: static[int]](table: array[N, float32], phase: uint): float32 =
  table[ index(N, phase) ]

proc lin*[N: static[int]](table: array[N, float32], phase: uint): float32 =
  let (index, fraction) = indexFraction(N, phase)
  table[index] + fraction * (table[(index + 1) and (N - 1)] - table[index])

proc herm*[N: static[int]](table: array[N, float32], phase: uint): float32 =
  # Hermite interpolation. This is more expensive for linear
  # Current tradeoff is this makes sense even for wavetables if you use the AVX2 version
  # This scalar version is fine for slower moving stuff
  #
  # adapted from https://github.com/pichenettes/stmlib/blob/master/dsp/dsp.h
  #
  # Thanks emilie!
  #
  # 'and indexHigh(N)' is efficient wrapping of index to 0..<N 
  # including when index is 0 and index - 1 wraps around to high(uint)
  # that gets masked away to the highest table index, which is what we want
  #
  let (index, fraction) = indexFraction(N, phase)
  let xm1 = table[ (index - 1) and indexHigh(N) ]
  let x0  = table[ index and indexHigh(N) ]
  let x1  = table[ (index + 1) and indexHigh(N) ]
  let x2  = table[ (index + 2) and indexHigh(N) ]
  let c = (x1 - xm1) * 0.5f32
  let v = x0 - x1
  let w = c + v
  let a = w + v + (x2 - x0) * 0.5f32
  let b_neg = w + a
  result = (((a * fraction) - b_neg) * fraction + c) * fraction + x0

# tableless oscillators
template saw*(phase: uint): float32 =
  # Convert phase to float in range [0, 1) and scale to [-1, 1)
  # Use 64-bit arithmetic but handle precision carefully
  float32((phase.float64 / (high(uint).float64 + 1.0)) * 2.0 - 1.0)

template sawd*(phase: uint): float32 =
  # Downward sawtooth: starts at 1, goes to -1
  # Use 64-bit arithmetic but handle precision carefully
  float32(1.0 - (phase.float64 / (high(uint).float64 + 1.0)) * 2.0)

proc pulse*(phase: uint, width: range[0'f..1'f] = 0.5): float32 = 
  # Square wave: -1 for first part, +1 for second part
  # Use 64-bit arithmetic but handle precision carefully
  let normalized = phase.float64 / (high(uint).float64 + 1.0)
  if normalized < width.float64:
    -1.0f
  else:
    1.0f

template triangle*(phase: uint): float32 =
 cast[float32](((phase xor (0 - uint(phase > high(uint) shr 1))) shr 7) or 0x40000000'u32) - 3.0f

#[
template triangle*(phase: uint, slope: range[0'f..1'f] = 0.5): float32 =
 let pivot = uint(slope * float(high(uint)))
 let mask = 0 - uint(phase > pivot)
 let scaled = ((phase * high(uint)) div (pivot + mask and (high(uint) - 2 * pivot))) xor mask
 cast[float32]((scaled shr 7) or 0x40000000'u32) - 3.0f
]#

template triangle*(phase: uint, slope: range[0'f..1'f] = 0.5): float32 =
  let pivot = uint(slope * float(high(uint)))
  let mask = 0 - uint(phase > pivot)
  let up_phase = phase * high(uint) div pivot
  let down_phase = high(uint) - ((phase - pivot) * high(uint) div (high(uint) - pivot))
  let result = (up_phase and (not mask)) or (down_phase and mask)
  cast[float32]((result shr 7) or 0x40000000'u32) - 3.0f


# Table generators
proc fillSine*[N: static[int]](table: var array[N, float32]) =
  for i in 0..<N:
    table[i] = sin(2.0 * PI * float32(i) / float32(N))

proc fillSine*[N: static[int]](): array[N, float32] =
  fillSine(result)



