import audio/[context, signal]
import math
import std

proc `+`*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = a.f(ctx) + b.f(ctx),
    label: "(" && a.label && " + " && b.label && ")"
  )

proc sum*(signals: varargs[Signal]): Signal =
  var xs = newSeq[Signal](signals.len) 
  for i in 0..<signals.len:
    xs[i] = signals[i]
  proc f(ctx: Context): float =
    for x in xs:
      result += x.f(ctx)
  Signal(f: f)

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

proc `*`*(a: float, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = a * b.f(ctx),
    label: "(" && $a && " * " && b.label && ")"
  )

proc `*`*(a: Signal, b: float): Signal =
  Signal(
    f: proc(ctx: Context): float = a.f(ctx) * b,
    label: "(" && a.label && " * " && $b && ")"
  )

proc `*`*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = a.f(ctx) * b.f(ctx),
    label: "(" && a.label && " * " && b.label && ")"
  )

proc prod*(signals: varargs[Signal]): Signal =
  var xs = newSeq[Signal](signals.len) 
  for i in 0..<signals.len:
    xs[i] = signals[i]
  proc f(ctx: Context): float =
    result = 1.0
    for x in xs:
      result *= x.f(ctx)
  Signal(f: f)

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

proc `!=`*(x: Signal, y: Signal): Signal =
  proc f(ctx: Context): float =
    if x.f(ctx) != y.f(ctx):
      return 1.0
    else:
      return 0.0
  Signal(f: f, label: "(" && x.label && " != " && y.label && ")")

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

proc equal*(x: Signal, y: Signal): Signal = x == y
proc notEqual*(x: Signal, y: Signal): Signal = x != y
proc less*(x: Signal, y: Signal): Signal = x < y
proc lessEqual*(x: Signal, y: Signal): Signal = x <= y
proc greater*(x: Signal, y: Signal): Signal = x > y
proc greaterEqual*(x: Signal, y: Signal): Signal = x >= y

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

proc min*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = min(a.f(ctx), b.f(ctx)),
    label: "min(" && a.label && ", " && b.label && ")"
  )

proc max*(a: Signal, b: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = max(a.f(ctx), b.f(ctx)),
    label: "max(" && a.label && ", " && b.label && ")"
  )

proc clip*(x: Signal, min: Signal = -1, max: Signal = 1): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let a = min.f(ctx)
    let b = max.f(ctx)
    return if x < a: a elif x > b: b else: x
  Signal(
    f: f,
    label: "clip(" && x.label && ", " && min.label && ", " && max.label && ")"
  )

proc wrap*(x: Signal, min: Signal = -1, max: Signal = 1): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let a = min.f(ctx)
    let b = max.f(ctx)
    return (x - a) mod (b - a) + a
  Signal(
    f: f,
    label: "wrap(" && x.label && ", " && min.label && ", " && max.label && ")"
  )

let exp* = exp.toSignal("exp")

proc sin*(phase: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = sin(PI * phase.f(ctx)),
    label: "sin(" && phase.label && ")"
  )

proc cos*(phase: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = cos(PI * phase.f(ctx)),
    label: "cos(" && phase.label && ")"
  )

proc tan*(phase: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = tan(PI * phase.f(ctx)),
    label: "tan(" && phase.label && ")"
  )

proc sinh*(phase: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = sinh(PI * phase.f(ctx)),
    label: "sinh(" && phase.label && ")"
  )

proc cosh*(phase: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = cosh(PI * phase.f(ctx)),
    label: "cosh(" && phase.label && ")"
  )

proc tanh*(phase: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = tanh(PI * phase.f(ctx)),
    label: "tanh(" && phase.label && ")"
  )

proc clausen*(phase: Signal, n: int = 100): Signal =
  proc f(ctx: Context): float =
    result = 0
    let phi = PI * phase.f(ctx)
    for i in 1..n:
      let k = i.toFloat
      result += sin(k*phi)/(k*k)
  Signal(f: f,  label: "clausen(" && phase.label && ")")

proc fsin*(x: float): float {.inline.} =
  var x = x
  while x > PI:
    x -= TWOPI
  while x < -PI:
    x += TWOPI

  const coeffs = [
    -0.10132118,          # x
     0.0066208798,        # x^3
    -0.00017350505,       # x^5
     0.0000025222919,     # x^7
    -0.000000023317787,   # x^9
     0.00000000013291342, # x^11
  ]
  const pi_major = 3.1415927
  const pi_minor = -0.00000008742278
  const pi = pi_major + pi_minor

  let x2 = x * x
  const p11 = coeffs[5]
  let p9  = p11 * x2 + coeffs[4]
  let p7  = p9  * x2 + coeffs[3]
  let p5  = p7  * x2 + coeffs[2]
  let p3  = p5  * x2 + coeffs[1]
  let p1  = p3  * x2 + coeffs[0]
  # result = (x - pi_major - pi_minor) * (x + pi_major + pi_minor) * p1 * x
  result = (x - pi) * (x + pi) * p1 * x

proc fsin*(phase: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = fsin(PI * phase.f(ctx)),
    label: "fsin(" && phase.label && ")"
  )

proc round*(x: Signal): Signal =
  Signal(
    f: proc(ctx: Context): float = x.f(ctx).round(),
    label: "round(" && x.label && ")"
  )
