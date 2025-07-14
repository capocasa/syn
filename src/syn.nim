import std/[math]
import nimsimd/avx2

{.passC: "-O3 -ffast-math -march=native -mtune=native".}

template addmod1*[T: SomeFloat](a, b: T): T =
  (a + b) mod 1.0

template incmod1*(a: var float32, b: float32) =
  a = a addmod1 b

proc herm*(table: openArray[float32], phase: float32): float32 =
  let scaledIndex = phase * float32(table.len - 3)
  let index_integral = int32(scaledIndex) + 1
  let index_fractional = scaledIndex - float32(index_integral - 1)
  let xm1 = table[index_integral - 1]
  let x0  = table[index_integral + 0]
  let x1  = table[index_integral + 1]
  let x2  = table[index_integral + 2]
  let c = (x1 - xm1) * 0.5f32
  let v = x0 - x1
  let w = c + v
  let a = w + v + (x2 - x0) * 0.5f32
  let b_neg = w + a
  let f = index_fractional
  result = (((a * f) - b_neg) * f + c) * f + x0

proc herm*(table: openArray[float32], phases: openArray[float32]): seq[float32] =
  assert phases.len mod 16 == 0, "phases.len must be divisible by 16"
  result = newSeq[float32](phases.len)
  let tableLen = float32(table.len - 3)
  let tableLenVec = mm256_set1_ps(tableLen)
  let halfVec = mm256_set1_ps(0.5f32)
  let oneVec = mm256_set1_epi32(1)
  
  let phasesPtr = cast[ptr float32](phases[0].unsafeAddr)
  let resultPtr = cast[ptr float32](result[0].addr)
  let tablePtr = cast[ptr float32](table[0].unsafeAddr)
  
  var i = 0
  while i < phases.len:
    # Process two 256-bit vectors (16 values) per iteration
    let phaseVec1 = mm256_loadu_ps(cast[ptr float32](cast[int](phasesPtr) + i * sizeof(float32)))
    let phaseVec2 = mm256_loadu_ps(cast[ptr float32](cast[int](phasesPtr) + (i + 8) * sizeof(float32)))
    
    # First 8 values
    let scaledIndexVec1 = mm256_mul_ps(phaseVec1, tableLenVec)
    let indexIntegralVec1 = mm256_add_epi32(mm256_cvtps_epi32(scaledIndexVec1), oneVec)
    let indexFractionalVec1 = mm256_sub_ps(scaledIndexVec1, mm256_cvtepi32_ps(mm256_sub_epi32(indexIntegralVec1, oneVec)))
    
    # Second 8 values
    let scaledIndexVec2 = mm256_mul_ps(phaseVec2, tableLenVec)
    let indexIntegralVec2 = mm256_add_epi32(mm256_cvtps_epi32(scaledIndexVec2), oneVec)
    let indexFractionalVec2 = mm256_sub_ps(scaledIndexVec2, mm256_cvtepi32_ps(mm256_sub_epi32(indexIntegralVec2, oneVec)))
    
    # Vectorized gather operations for first 8 values
    let xm1Vec1 = mm256_i32gather_ps(tablePtr, mm256_sub_epi32(indexIntegralVec1, oneVec), 4)
    let x0Vec1 = mm256_i32gather_ps(tablePtr, indexIntegralVec1, 4)
    let x1Vec1 = mm256_i32gather_ps(tablePtr, mm256_add_epi32(indexIntegralVec1, oneVec), 4)
    let x2Vec1 = mm256_i32gather_ps(tablePtr, mm256_add_epi32(indexIntegralVec1, mm256_set1_epi32(2)), 4)
    
    # Vectorized gather operations for second 8 values
    let xm1Vec2 = mm256_i32gather_ps(tablePtr, mm256_sub_epi32(indexIntegralVec2, oneVec), 4)
    let x0Vec2 = mm256_i32gather_ps(tablePtr, indexIntegralVec2, 4)
    let x1Vec2 = mm256_i32gather_ps(tablePtr, mm256_add_epi32(indexIntegralVec2, oneVec), 4)
    let x2Vec2 = mm256_i32gather_ps(tablePtr, mm256_add_epi32(indexIntegralVec2, mm256_set1_epi32(2)), 4)
    
    # Hermite interpolation for first 8 values
    let cVec1 = mm256_mul_ps(mm256_sub_ps(x1Vec1, xm1Vec1), halfVec)
    let vVec1 = mm256_sub_ps(x0Vec1, x1Vec1)
    let wVec1 = mm256_add_ps(cVec1, vVec1)
    let aVec1 = mm256_add_ps(mm256_add_ps(wVec1, vVec1), mm256_mul_ps(mm256_sub_ps(x2Vec1, x0Vec1), halfVec))
    let bNegVec1 = mm256_add_ps(wVec1, aVec1)
    
    let fVec1 = indexFractionalVec1
    let resultVec1 = mm256_add_ps(
      mm256_mul_ps(
        mm256_add_ps(
          mm256_mul_ps(
            mm256_sub_ps(
              mm256_mul_ps(aVec1, fVec1),
              bNegVec1
            ),
            fVec1
          ),
          cVec1
        ),
        fVec1
      ),
      x0Vec1
    )
    
    # Hermite interpolation for second 8 values
    let cVec2 = mm256_mul_ps(mm256_sub_ps(x1Vec2, xm1Vec2), halfVec)
    let vVec2 = mm256_sub_ps(x0Vec2, x1Vec2)
    let wVec2 = mm256_add_ps(cVec2, vVec2)
    let aVec2 = mm256_add_ps(mm256_add_ps(wVec2, vVec2), mm256_mul_ps(mm256_sub_ps(x2Vec2, x0Vec2), halfVec))
    let bNegVec2 = mm256_add_ps(wVec2, aVec2)
    
    let fVec2 = indexFractionalVec2
    let resultVec2 = mm256_add_ps(
      mm256_mul_ps(
        mm256_add_ps(
          mm256_mul_ps(
            mm256_sub_ps(
              mm256_mul_ps(aVec2, fVec2),
              bNegVec2
            ),
            fVec2
          ),
          cVec2
        ),
        fVec2
      ),
      x0Vec2
    )
    
    # Store results
    mm256_storeu_ps(cast[ptr float32](cast[int](resultPtr) + i * sizeof(float32)), resultVec1)
    mm256_storeu_ps(cast[ptr float32](cast[int](resultPtr) + (i + 8) * sizeof(float32)), resultVec2)
    i += 16


