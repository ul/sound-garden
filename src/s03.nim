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
      return (cycles * ctx.sampleRate).toFloat / m
    else:
      return ctx.sampleRate.toFloat
  Signal(f: f, label: "pitch(" && x.label && ")")

proc lpfFreqToAlpha(ctx: Context, freq: float): float =
  let k = freq * ctx.sampleAngularPeriod
  return k / (k + 1)

proc lpf*(x: Signal, freq: Signal): Signal =
  proc f(ctx: Context): float =
    let α = ctx.lpfFreqToAlpha(freq.f(ctx))
    result = ctx.lastSample + α * (x.f(ctx) - ctx.lastSample)
  Signal(f: f, label: "lpf(" && x.label && ", " && freq.label && ")").mult

proc hpfFreqToAlpha(ctx: Context, freq: float): float =
  let k = freq * ctx.sampleAngularPeriod
  return 1 / (k + 1)

proc hpf*(x: Signal, freq: Signal): Signal =
  let lastX = x.prime
  proc f(ctx: Context): float =
    let α = ctx.hpfFreqToAlpha(freq.f(ctx))
    result = α * (ctx.lastSample + x.f(ctx) - lastX.f(ctx))
  Signal(f: f, label: "hpf(" && x.label && ", " && freq.label && ")").mult

proc makeBiQuadFilter(makeCoefficients: proc(sinω, cosω, α: float): array[6, float]):
  proc(x, freq: Signal, Q: Signal = 0.7071): Signal =
  proc filter(x, freq: Signal, Q: Signal = 1): Signal =
    let x1 = x.prime
    let x2 = x1.prime
    var y2s: array[SOUNDIO_MAX_CHANNELS, float]
    proc f(ctx: Context): float =
      let i    = ctx.channel
      let x    = x.f(ctx)
      let x1   = x1.f(ctx)
      let x2   = x2.f(ctx)
      let y1   = ctx.lastSample
      let y2   = y2s[i]
      let ω    = freq.f(ctx) * ctx.sampleAngularPeriod
      let sinω = ω.sin
      let cosω = ω.cos
      let α    = sinω / (2.0 * Q.f(ctx))
      let c    = makeCoefficients(sinω, cosω, α)
      let b0   = c[0]
      let b1   = c[1]
      let b2   = c[2]
      let a0   = c[3]
      let a1   = c[4]
      let a2   = c[5]
      result   = (x * b0 + x1 * b1 + x2 * b2 - y1 * a1 - y2 * a2) / a0
      y2s[i]   = y1
    Signal(f: f, label: x.label).mult
  return filter

proc makeLPFCoefficients(sinω, cosω, α: float): array[6, float] =
  let b1 = 1.0 - cosω
  let b0 = 0.5 * b1
  result = [b0, b1, b0, 1.0 + α, -2.0 * cosω, 1.0 - α]

proc makeHPFCoefficients(sinω, cosω, α: float): array[6, float] =
  let k = 1.0 + cosω
  let b0 = 0.5 * k
  let b1 = -k
  result = [b0, b1, b0, 1.0 + α, -2.0 * cosω, 1.0 - α]

let makeBiQuadLPF = makeBiQuadFilter(makeLPFCoefficients)
proc biQuadLPF*(x, freq: Signal, Q: Signal = 0.7071): Signal =
  result = makeBiQuadLPF(x, freq, Q)
  result.label = "biQuadLPF(" && x.label && ", " && freq.label && ", " && Q.label && ")"

let makeBiQuadHPF = makeBiQuadFilter(makeHPFCoefficients)
proc biQuadHPF*(x, freq: Signal, Q: Signal = 0.7071): Signal =
  result = makeBiQuadHPF(x, freq, Q)
  result.label = "biQuadHPF(" && x.label && ", " && freq.label && ", " && Q.label && ")"

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

