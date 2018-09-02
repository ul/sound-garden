import audio/[context, signal]
import math
import maths
import random
import soundio
import std

randomize()

let silence* = 0

# TODO is it skewed with unreachable 1.0?
let whiteNoise* = Signal(f: proc(ctx: Context): float = rand(2.0) - 1.0, label: "whiteNoise")

proc project*(x, c, d: Signal): Signal =
  const a = -1.0
  const b = 1.0
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let c = c.f(ctx)
    let d = d.f(ctx)
    return (d - c) * (x - a) / (b - a) + c
  Signal(f: f, label: "project(" && x.label && ", " && c.label && ", " && d.label && ")")

proc circle*(x: Signal): Signal = x.project(-PI, PI)
proc unit*(x: Signal): Signal = x.project(0.0, 1.0)

proc sampleAndHold*(trig: Signal, x: Signal): Signal =
  var samples: array[SOUNDIO_MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let i = ctx.channel
    let t = trig.f(ctx)
    let x = x.f(ctx)
    result = samples[i] * (1-t) + x * t
    samples[i] = result
  Signal(f: f, label: "sampleAndHold(" && trig.label && ", " && x.label && ")").mult


