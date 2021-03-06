import audio/[context, signal]
import math
import maths
import random
import soundio
import std

randomize()

let silence* = 0.toSignal
let zero* = silence

# TODO is it skewed with unreachable 1.0?
let whiteNoise* = Signal(f: proc(ctx: Context): float = rand(2.0) - 1.0, label: "whiteNoise")

# TODO exponential projection
proc project*(x, a, b, c, d: Signal): Signal =
  result = (d - c) * (x - a) / (b - a) + c
  result.label = "project(" &&
    x.label && ", " &&
    a.label && ", " &&
    b.label && ", " &&
    c.label && ", " &&
    d.label && ")"

proc range*(x, a, b: Signal): Signal = x.project(-1, 1, a, b)
proc circle*(x: Signal): Signal = x.range(-PI, PI)
proc unit*(x: Signal): Signal = x.range(0.0, 1.0)

proc sampleAndHold*(t, x: Signal): Signal =
  result = Signal()
  let y = result.mult
  proc f(ctx: Context): float =
    let t = t.f(ctx)
    let x = x.f(ctx)
    let y = y.f(ctx)
    return (1.0 - t) * y + t * x
  result.f = f
  result.label = "sampleAndHold(" && t.label && ", " && x.label && ")"

proc sampleAndHoldSharp*(t, x: Signal): Signal =
  result = Signal()
  let y = result.mult
  proc f(ctx: Context): float =
    # pre-computing before condition because otherwise
    # values are optimized out for somewhat reason
    let x = x.f(ctx)
    let y = y.f(ctx)
    let t = t.f(ctx)
    return if t > 0.0: x else: y
  result.f = f
  result.label = "sampleAndHoldSharp(" && t.label && ", " && x.label && ")"

proc sampleAndHoldStart*(t, x: Signal): Signal =
  result = Signal()
  let y = result.mult
  let p = t.prime
  proc f(ctx: Context): float =
    # pre-computing before condition because otherwise
    # values are optimized out for somewhat reason
    let x = x.f(ctx)
    let y = y.f(ctx)
    let p = p.f(ctx)
    let t = t.f(ctx)
    return if (p <= 0.0) and (t > 0.0): x else: y
  result.f = f
  result.label = "sampleAndHoldStart(" && t.label && ", " && x.label && ")"

proc sampleAndHoldEnd*(t, x: Signal): Signal =
  result = Signal()
  let y = result.mult
  let p = t.prime
  proc f(ctx: Context): float =
    # pre-computing before condition because otherwise
    # values are optimized out for somewhat reason
    let x = x.f(ctx)
    let y = y.f(ctx)
    let p = p.f(ctx)
    let t = t.f(ctx)
    return if (p > 0.0) and (t <= 0.0): x else: y
  result.f = f
  result.label = "sampleAndHoldEnd(" && t.label && ", " && x.label && ")"

proc timeSince*(t: Signal): Signal = signal.time - t.sampleAndHoldSharp(signal.time)
proc timeSinceStart*(t: Signal): Signal = signal.time - t.sampleAndHoldStart(signal.time)

proc sampleSince*(t: Signal): Signal = sampleNumber - t.sampleAndHoldSharp(sampleNumber)
proc sampleSinceStart*(t: Signal): Signal = sampleNumber - t.sampleAndHoldStart(sampleNumber)

proc db2amp*(x: float): float = 20.0 * x.log10
proc amp2db*(x: float): float = 10.pow(x / 20.0)

proc freq2midi*(x: float): float = 69.0 + 12.0 * log2(x / 440.0)
proc midi2freq*(x: float): float = 440.0 * 2.pow((x - 69.0) / 12.0)

proc quantize*(x: Signal, step: Signal): Signal =
  result = (x / step).round * step

let input* = Signal(
  f: proc(ctx: Context): float = ctx.input,
  label: "input"
)

