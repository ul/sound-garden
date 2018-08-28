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

proc uuu*(x: Signal): Signal =
  result = (x.prime < 0) and (x >= 0)
  result.label = "uuu(" && x.label && ")"

proc nnn*(x: Signal): Signal =
  var counts: array[SOUNDIO_MAX_CHANNELS, float]
  let u = x.uuu
  proc f(ctx: Context): float =
    let i = ctx.channel
    if u.f(ctx) == 0.0:
      counts[i] += 1.0
    else:
      counts[i] = 0.0
    return counts[i]
  Signal(f: f, label: "nnn(" && x.label && ")").mult

proc mmm*(x: Signal): Signal =
  let n = x.nnn
  result = sampleAndHold(n == 0, n.prime + 1)
  result.label = "mmm(" && x.label && ")"

proc pitch*(x: Signal): Signal =
  let m = x.mmm
  proc f(ctx: Context): float =
    let m = m.f(ctx)
    if m > 0:
      return ctx.sampleRate.toFloat / m
    else:
      return 0
  Signal(f: f, label: "pitch(" && x.label && ")")

