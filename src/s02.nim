import audio/[context, signal]
import math

proc `+`*(a: Signal, b: Signal): Signal =
  Signal(f: proc(ctx: Context): float = a.f(ctx) + b.f(ctx))

# Consider checking if the first operand is zero and short-circuiting
# It could help to reduce load when envelopes are involved
proc `*`*(a: Signal, b: Signal): Signal =
  Signal(f: proc(ctx: Context): float = a.f(ctx) * b.f(ctx))

proc `-`*(a: Signal, b: Signal): Signal =
  Signal(f: proc(ctx: Context): float = a.f(ctx) - b.f(ctx))

proc `/`*(a: Signal, b: Signal): Signal =
  Signal(f: proc(ctx: Context): float = a.f(ctx) / b.f(ctx))

# Convenient for chaining
proc add*(a: Signal, b: Signal): Signal = a + b
proc mul*(a: Signal, b: Signal): Signal = a * b
proc sub*(a: Signal, b: Signal): Signal = a - b
proc `div`*(a: Signal, b: Signal): Signal = a / b
proc `mod`*(a: Signal, b: Signal): Signal =
  Signal(f: proc(ctx: Context): float = a.f(ctx) mod b.f(ctx))

proc clip*(input: Signal, min: Signal = -1, max: Signal = 1): Signal =
  proc f(ctx: Context): float =
    let x = input.f(ctx)
    let a = min.f(ctx)
    let b = max.f(ctx)
    return if x < a: a elif x > b: b else: x
  Signal(f: f)

proc wrap*(input: Signal, min: Signal = -1, max: Signal = 1): Signal =
  proc f(ctx: Context): float =
    let x = input.f(ctx)
    let a = min.f(ctx)
    let b = max.f(ctx)
    return (x - a) mod (b - a) + a 
  Signal(f: f)

