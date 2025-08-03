## State variable filter (SVF), designed by Andrew Simper of Cytomic.
##
## http://cytomic.com/files/dsp/SvfLinearTrapOptimised2.pdf
##
## The frequency response of this filter is the same as of BZT filters.
## This is a second-order filter. It has a cutoff slope of 12 dB/octave.
## Q = 0.707 means no resonant peaking.
##
## This filter will self-oscillate when Q is very high (can be forced by
## setting the `k` coefficient to zero).
##
## This filter is stable when modulated at high rates.
##
## This implementation uses the generic formulation that can morph between the
## different responses by altering the mix coefficients m0, m1, m2.

import math

type
  StateVariableFilter* = object
    g*, k*, a1*, a2*, a3*: float64    ## filter coefficients
    m0*, m1*, m2*: float32            ## mix coefficients  
    ic1eq*, ic2eq*: float32           ## internal state

proc initStateVariableFilter*(): StateVariableFilter =
  ## Initialize a new StateVariableFilter with default values
  result.m0 = 0.0
  result.m1 = 0.0
  result.m2 = 0.0

proc setCoefficients*(filter: var StateVariableFilter, sampleRate, freq, Q: float64) =
  ## Set the basic filter coefficients
  filter.g = tan(PI * freq / sampleRate)
  filter.k = 1.0 / Q
  filter.a1 = 1.0 / (1.0 + filter.g * (filter.g + filter.k))
  filter.a2 = filter.g * filter.a1
  filter.a3 = filter.g * filter.a2

proc lowpass*(filter: var StateVariableFilter, sampleRate, freq, Q: float64) =
  ## Configure as lowpass filter
  filter.setCoefficients(sampleRate, freq, Q)
  filter.m0 = 0.0
  filter.m1 = 0.0
  filter.m2 = 1.0

proc highpass*(filter: var StateVariableFilter, sampleRate, freq, Q: float64) =
  ## Configure as highpass filter
  filter.setCoefficients(sampleRate, freq, Q)
  filter.m0 = 1.0
  filter.m1 = -filter.k
  filter.m2 = -1.0

proc bandpass*(filter: var StateVariableFilter, sampleRate, freq, Q: float64) =
  ## Configure as bandpass filter
  filter.setCoefficients(sampleRate, freq, Q)
  filter.m0 = 0.0
  filter.m1 = filter.k  # paper says 1, but that is not same as RBJ bandpass
  filter.m2 = 0.0

proc notch*(filter: var StateVariableFilter, sampleRate, freq, Q: float64) =
  ## Configure as notch filter
  filter.setCoefficients(sampleRate, freq, Q)
  filter.m0 = 1.0
  filter.m1 = -filter.k
  filter.m2 = 0.0

proc allpass*(filter: var StateVariableFilter, sampleRate, freq, Q: float64) =
  ## Configure as allpass filter
  filter.setCoefficients(sampleRate, freq, Q)
  filter.m0 = 1.0
  filter.m1 = -2.0 * filter.k
  filter.m2 = 0.0

proc peaking*(filter: var StateVariableFilter, sampleRate, freq, Q: float64) =
  ## Configure as peaking filter
  ## Note: This is not the same as the RBJ peaking filter, since no dbGain.
  filter.setCoefficients(sampleRate, freq, Q)
  filter.m0 = 1.0
  filter.m1 = -filter.k
  filter.m2 = -2.0

proc bell*(filter: var StateVariableFilter, sampleRate, freq, Q, dbGain: float64) =
  ## Configure as bell filter  
  ## Note: This is the same as the RBJ peaking EQ.
  let A = pow(10.0, dbGain / 40.0)
  filter.g = tan(PI * freq / sampleRate)
  filter.k = 1.0 / (Q * A)
  filter.a1 = 1.0 / (1.0 + filter.g * (filter.g + filter.k))
  filter.a2 = filter.g * filter.a1
  filter.a3 = filter.g * filter.a2
  filter.m0 = 1.0
  filter.m1 = filter.k * (A*A - 1.0)
  filter.m2 = 0.0

proc lowShelf*(filter: var StateVariableFilter, sampleRate, freq, Q, dbGain: float64) =
  ## Configure as low shelf filter
  let A = pow(10.0, dbGain / 40.0)
  filter.g = tan(PI * freq / sampleRate) / sqrt(A)
  filter.k = 1.0 / Q
  filter.a1 = 1.0 / (1.0 + filter.g * (filter.g + filter.k))
  filter.a2 = filter.g * filter.a1
  filter.a3 = filter.g * filter.a2
  filter.m0 = 1.0
  filter.m1 = filter.k * (A - 1.0)
  filter.m2 = (A*A - 1.0)

proc highShelf*(filter: var StateVariableFilter, sampleRate, freq, Q, dbGain: float64) =
  ## Configure as high shelf filter
  let A = pow(10.0, dbGain / 40.0)
  filter.g = tan(PI * freq / sampleRate) * sqrt(A)
  filter.k = 1.0 / Q
  filter.a1 = 1.0 / (1.0 + filter.g * (filter.g + filter.k))
  filter.a2 = filter.g * filter.a1
  filter.a3 = filter.g * filter.a2
  filter.m0 = A * A
  filter.m1 = filter.k * (1.0 - A) * A
  filter.m2 = (1.0 - A*A)

proc reset*(filter: var StateVariableFilter) =
  ## Reset the filter's internal state
  filter.ic1eq = 0.0
  filter.ic2eq = 0.0

proc next*(filter: var StateVariableFilter, v0: float32): float32 =
  ## Process a single sample through the filter
  let v3 = v0 - filter.ic2eq
  let v1 = filter.a1 * filter.ic1eq + filter.a2 * v3
  let v2 = filter.ic2eq + filter.a2 * filter.ic1eq + filter.a3 * v3
  filter.ic1eq = 2.0 * v1 - filter.ic1eq
  filter.ic2eq = 2.0 * v2 - filter.ic2eq
  return filter.m0 * v0 + filter.m1 * v1 + filter.m2 * v2
