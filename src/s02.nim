import audio/[context, signal]
import math
import std

proc `+`*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = a.f(ctx) + b.f(ctx),
    label: "(" && a.label && " + " && b.label && ")"
  )

# NOTE short circuiting on the first operand being zero to allow
# efficient triggered envelopes trick
proc `.*`*(a: Signal, b: Signal): Signal =
  proc f(ctx: Context): float =
    let x = a.f(ctx)
    if x < 1e-6:
      return 0.0
    else:
     return x * b.f(ctx)
  Signal(f: f, label: "(" && a.label && " * " && b.label && ")")

# NOTE short circuiting on the second operand being zero to allow
# efficient triggered envelopes trick
proc `*.`*(a: Signal, b: Signal): Signal =
  proc f(ctx: Context): float =
    let x = b.f(ctx)
    if x < 1e-6:
      return 0.0
    else:
     return x * a.f(ctx)
  Signal(f: f, label: "(" && a.label && " * " && b.label && ")")

proc `*`*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = a.f(ctx) * b.f(ctx),
    label: "(" && a.label && " * " && b.label && ")"
  )

proc `-`*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = a.f(ctx) - b.f(ctx),
    label: "(" && a.label && " - " && b.label && ")"
  )

proc `/`*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = a.f(ctx) / b.f(ctx),
    label: "(" && a.label && " / " && b.label && ")"
  )

proc `and`*(a: Signal, b: Signal): Signal =
  proc f(ctx: Context): float =
    if a.f(ctx) == 1.0 and b.f(ctx) == 1.0:
      return 1.0
    else:
      return 0.0
  Signal(f: f, label: "(" && a.label && " and " && b.label && ")")

proc `or`*(a: Signal, b: Signal): Signal =
  proc f(ctx: Context): float =
    if a.f(ctx) == 1.0 or b.f(ctx) == 1.0:
      return 1.0
    else:
      return 0.0
  Signal(f: f, label: "(" && a.label && " or " && b.label && ")")

proc `==`*(x: Signal, y: Signal): Signal =
  proc f(ctx: Context): float =
    if x.f(ctx) == y.f(ctx):
      return 1.0
    else:
      return 0.0
  Signal(f: f, label: "(" && x.label && " == " && y.label && ")")

proc `<`*(x: Signal, y: Signal): Signal =
  proc f(ctx: Context): float =
    if x.f(ctx) < y.f(ctx):
      return 1.0
    else:
      return 0.0
  Signal(f: f, label: "(" && x.label && "< " && y.label && ")")

proc `<=`*(x: Signal, y: Signal): Signal =
  proc f(ctx: Context): float =
    if x.f(ctx) <= y.f(ctx):
      return 1.0
    else:
      return 0.0
  Signal(f: f, label: "(" && x.label && " <= " && y.label && ")")

proc `>`*(x: Signal, y: Signal): Signal =
  proc f(ctx: Context): float =
    if x.f(ctx) > y.f(ctx):
      return 1.0
    else:
      return 0.0
  Signal(f: f, label: "(" && x.label && " > " && y.label && ")")

proc `>=`*(x: Signal, y: Signal): Signal =
  proc f(ctx: Context): float =
    if x.f(ctx) >= y.f(ctx):
      return 1.0
    else:
      return 0.0
  Signal(f: f, label: "(" && x.label && " >= " && y.label && ")")

# Convenient for chaining
proc add*(a: Signal, b: Signal): Signal = a + b
proc mul*(a: Signal, b: Signal): Signal = a * b
proc sub*(a: Signal, b: Signal): Signal = a - b
proc `div`*(a: Signal, b: Signal): Signal = a / b
proc `mod`*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = a.f(ctx) mod b.f(ctx),
    label: "(" && a.label && " mod " && b.label && ")"
  )

proc clip*(input: Signal, min: Signal = -1, max: Signal = 1): Signal =
  proc f(ctx: Context): float =
    let x = input.f(ctx)
    let a = min.f(ctx)
    let b = max.f(ctx)
    return if x < a: a elif x > b: b else: x
  Signal(
    f: f,
    label: "clip(" && input.label && ", " && min.label && ", " && max.label && ")"
  )

proc wrap*(input: Signal, min: Signal = -1, max: Signal = 1): Signal =
  proc f(ctx: Context): float =
    let x = input.f(ctx)
    let a = min.f(ctx)
    let b = max.f(ctx)
    return (x - a) mod (b - a) + a 
  Signal(
    f: f,
    label: "wrap(" && input.label && ", " && min.label && ", " && max.label && ")"
  )
