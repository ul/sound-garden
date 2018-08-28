import audio/[context, signal]
import math
import s02
import soundio
import std

# Faust you are godlike, thank you for telling me truth about panners
proc pan*(left, right: Signal; c: Signal = 0): Signal =
  proc f(ctx: Context): float =
    let c = c.f(ctx)
    let l = left.f(ctx)
    let r = right.f(ctx)
    result = case ctx.channel
    of 0: min(1, 1-c).sqrt * l + max(0,  -c).sqrt * r 
    of 1: max(0,   c).sqrt * l + min(1, 1+c).sqrt * r
    else: 0.0
  Signal(f: f, label: "pan(" && left.label && ", " && right.label && ", " && c.label && ")")

proc prime*(x: Signal): Signal =
  var samples: array[SOUNDIO_MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let i = ctx.channel
    result = samples[i]
    samples[i] = x.f(ctx)
  Signal(f: f, label: "prime(" && x.label && ")").mult

proc sampleAndHold*(trig: Signal, x: Signal): Signal =
  var samples: array[SOUNDIO_MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let i = ctx.channel
    let t = trig.f(ctx)
    let x = x.f(ctx)
    result = samples[i] * (1-t) + x * t
    samples[i] = result
  Signal(f: f, label: "sampleAndHold(" && trig.label && ", " && x.label && ")").mult

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
      result = (cycles * ctx.sampleRate).toFloat / m
  Signal(f: f, label: "pitch(" && x.label && ")")

