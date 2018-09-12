import audio/[context, signal]
import basics
import math
import maths
import soundio
import std

# NOTE apex is relative to start and is in seconds
proc impulse*(trigger, apex: Signal): Signal =
  let startSample = (trigger.prime <= 0.0 and trigger > 0.0).sampleAndHold(sampleNumber)
  let h = (sampleNumber - startSample) / (apex * sampleRate)
  result = h * maths.exp(1.0 - h)
  result.label = "impulse(" && trigger.label && ", " && apex.label && ")"

proc adsr*(trigger, a, d, s, r: Signal): Signal =
  let t = trigger.prime
  let startSample = (t <= 0.0 and trigger > 0.0).sampleAndHold(sampleNumber)
  let endSample = (t > 0.0 and trigger <= 0.0).sampleAndHold(sampleNumber)

  proc f(ctx: Context): float =
    let dur = ctx.sampleDuration
    let time = ctx.time
    let start = startSample.f(ctx) * dur
    let stop = endSample.f(ctx) * dur

    var delta = time - start
    let a = a.f(ctx)
    if delta <= a:
      return delta / a

    delta -= a
    let s = s.f(ctx)
    let d = d.f(ctx)
    if delta <= d:
      return 1.0 - (1.0 - s) * delta / d

    if start > stop:
      return s

    delta = time - max(start + a + d, stop)
    let r = r.f(ctx)
    if delta <= r:
      return s * (1.0 - delta / r)

    return 0.0

  Signal(
    f: f,
    label: "adsr(" &&
      trigger.label && ", " &&
      a.label && ", " &&
      d.label && ", " &&
      s.label && ", " &&
      r.label && ")" 
  )
