import audio/[context, signal]
import delays
import math
import maths
import soundio
import std

proc lpf*(x, freq: Signal): Signal =
  result = Signal()
  let y = result.mult
  let k = freq * signal.sampleAngularPeriod
  let α = k / (k + 1.0)
  result.f = (y + α * (x - y)).f
  result.label = "lpf(" && x.label && ", " && freq.label && ")"

proc hpf*(x, freq: Signal): Signal =
  result = Signal()
  let y = result.mult
  let k = freq * signal.sampleAngularPeriod
  let α = 1.0 / (k + 1.0)
  result.f = (α * (y + x - x.prime)).f
  result.label = "hpf(" && x.label && ", " && freq.label && ")"

proc makeBiQuadFilter(makeCoefficients: proc(sinω, cosω, α: float): array[6, float]):
  proc(x, freq, Q: Signal): Signal =
  proc filter(x, freq: Signal, Q: Signal = 0.7071): Signal =
    result = Signal()
    let x1 = x.prime
    let x2 = x1.prime
    let y1 = result.mult
    let y2 = y1.prime
    proc f(ctx: Context): float =
      let x    = x.f(ctx)
      let x1   = x1.f(ctx)
      let x2   = x2.f(ctx)
      let y1   = y1.f(ctx)
      let y2   = y2.f(ctx)
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
      result = (x * b0 + x1 * b1 + x2 * b2 - y1 * a1 - y2 * a2) / a0
    result.f = f
    result.label = x.label
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

proc feedback*(x, delayTime, gain: Signal): Signal =
  result = Signal()
  # max delay 5 seconds @ 48000 sample rate
  result.f = (x + gain * result.mult.delay(delayTime, 60 * 48000)).f 
  result.label = "feedback(" && x.label && ", " && delayTime.label && ", " && gain.label && ")"

proc smoothFeedback*(x, delayTime, gain: Signal): Signal =
  result = Signal()
  # max delay 5 seconds @ 48000 sample rate
  result.f = (x + gain * result.mult.smoothDelay(delayTime, 32, 60 * 48000)).f
  result.label = "smoothFeedback(" && x.label && ", " && delayTime.label && ", " && gain.label && ")"
