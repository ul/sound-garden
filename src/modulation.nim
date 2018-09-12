import audio/[context, signal]
import basics
import math
import maths
import oscillators
import std

proc fm*(carrierFreq, modulationFreq, r: Signal; phase0: Signal = 0): Signal =
  let k = 1 + r * modulationFreq.sine(phase0)
  let freq = k * carrierFreq
  return freq.sine(phase0)

proc pm*(carrierFreq, modulationFreq, r: Signal; phase0: Signal = 0): Signal =
  carrierFreq.sine(r * modulationFreq.sine(phase0) + phase0)

