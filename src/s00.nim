import audio/[context, signal]
import random

randomize()

let silence* = 0.toSignal

# TODO is it skewed with unreachable 1.0?
let whiteNoise* = Signal(f: proc(ctx: Context): float = rand(2.0) - 1.0)
