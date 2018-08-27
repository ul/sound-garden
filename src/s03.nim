import audio/[context, signal]
import math
import std

# Faust you are godlike, thank you for telling me truth about panners
proc pan*(left, right: Signal; c: Signal = 0): Signal =
  proc f(ctx: Context): float =
    let c = c.f(ctx)
    let l = left.f(ctx)
    let r = right.f(ctx)
    result = case ctx.channel
    of 0: min(1, 1-c).sqrt * l + max(0,  -c).sqrt * r 
    of 1: max(0,   c).sqrt * l + min(1, 1+c).sqrt * r
    else: 0.0
  Signal(f: f, label: "pan(" && left.label && ", " && right.label && ", " && c.label && ")" )
