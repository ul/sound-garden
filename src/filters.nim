import audio/[context, signal]
import delays
import math
import maths
import soundio
import std

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

proc feedbackSeed(previous, x, delayTime, gain: Signal): Signal =
  result = x + gain * previous.delay(delayTime, 5 * 48000) # max delay 5 seconds @ 48000 sample rate
  result.label = "feedback(" && x.label && ", " && delayTime.label && ", " && gain.label && ")"

let feedback* = feedbackSeed.recur
