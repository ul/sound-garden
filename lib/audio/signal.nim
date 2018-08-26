import context
import math
import std

const TWOPI* = 2.0 * PI

type
  Signal* = ref object
    f*: proc(ctx: Context): float
  FF = proc(x: float): float
  Function = proc(x: Signal): Signal

converter toSignal*(x: float): Signal =
  proc f(ctx: Context): float = x
  Signal(f: f)

converter toSignal*(x: int): Signal = x.toFloat.toSignal

converter toSignal*(x: Box[float]): Signal =
  proc f(ctx: Context): float = x.get
  Signal(f: f)

converter toSignal*(x: Box[int]): Signal =
  proc f(ctx: Context): float = x.get.toFloat
  Signal(f: f)

converter toSignal*(x: FF): Function =
  proc function(input: Signal): Signal =
    proc f(ctx: Context): float = x(input.f(ctx))
    Signal(f: f)
  return function

proc channel*(s: Signal, i: int = 0): Signal =
  var sample: float
  proc f(ctx: Context): float =
    if ctx.channel == i:
      sample = s.f(ctx)
    sample
  Signal(f: f)

proc linlin*(a, b, c, d: float): FF =
  let k = (d - c) / (b - a)
  proc f(x: float): float = k * (x - a) + c
  return f
