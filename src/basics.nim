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

proc sampleAndHoldZ(previous, t, x: Signal): Signal =
  result = (1 - t) * previous + t * x
  result.label = "sampleAndHold(" && t.label && ", " && x.label && ")"

let sampleAndHold* =  sampleAndHoldZ.recur
