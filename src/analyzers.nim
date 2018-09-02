import audio/[context, signal]
import basics
import delays
import filters
import math
import maths
import soundio
import std

proc zeroCrossUp*(x: Signal): Signal =
  result = (x.prime < 0) and (x >= 0)
  result.label = "zeroCrossUp(" && x.label && ")"

proc countZeroCrosses*(x: Signal, cycles: int = 10): Signal =
  var counts: array[SOUNDIO_MAX_CHANNELS, float]
  var cs: array[SOUNDIO_MAX_CHANNELS, int]
  let u = x.zeroCrossUp
  proc f(ctx: Context): float =
    let i = ctx.channel
    if u.f(ctx) == 0.0:
      counts[i] += 1.0
    else:
      cs[i] = (cs[i]+1) mod cycles
      if cs[i] == 0:
        counts[i] = 0.0
      else:
        counts[i] += 1.0
    return counts[i]
  Signal(f: f, label: "countZeroCrosses(" && x.label && ")").mult

proc zeroCrosses*(x: Signal, cycles: int = 10): Signal =
  let n = x.countZeroCrosses(cycles)
  result = sampleAndHold(n == 0, n.prime + 1)
  result.label = "zeroCrosses(" && x.label && ")"

proc pitch*(x: Signal, cycles: int = 10): Signal =
  let m = x.zeroCrosses(cycles)
  proc f(ctx: Context): float =
    let m = m.f(ctx)
    if m > 0:
      return (cycles * ctx.sampleRate).toFloat / m
    else:
      return ctx.sampleRate.toFloat
  Signal(f: f, label: "pitch(" && x.label && ")")

proc adaptivePitch*(x: Signal, cycles: int = 10): Signal =
  var freqs: array[SOUNDIO_MAX_CHANNELS, Box[float]]
  for i in 0..<SOUNDIO_MAX_CHANNELS:
    freqs[i] = box(10000.0)
  let freq = Signal(f: proc(ctx: Context): float = freqs[ctx.channel].get)
  let m = x.biQuadLPF(freq).zeroCrosses(cycles)
  proc f(ctx: Context): float =
    let m = m.f(ctx)
    if m > 0:
      result = (cycles * ctx.sampleRate).toFloat / m
      freqs[ctx.channel].set(result)
    else:
      return ctx.sampleRate.toFloat
  Signal(f: f, label: "adaptivePitch(" && x.label && ")").mult

