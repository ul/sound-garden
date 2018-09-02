import audio/[context, signal]
import basics
import delays
import math
import soundio
import std

# NOTE apex is relative to start and is in seconds
proc impulse*(start, apex: Signal): Signal =
  let startSample = start.sampleAndHold(sampleNumber)
  proc f(ctx: Context): float =
    let s = startSample.f(ctx)
    let t = ctx.sampleNumber.toFloat
    if s <= t:
      let h = (t - s) / (apex.f(ctx) * ctx.sampleRate.toFloat)
      return h * exp(1.0 - h)
    else:
      return 0.0
  Signal(f: f, label: "impulse(" && start.label && ", " && apex.label && ")")

