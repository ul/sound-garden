import audio/[context, signal]
import basics
import math
import maths
import soundio
import std

proc impulse*(trigger, apex: Signal): Signal =
  let h = trigger.timeSinceStart / apex
  result = h * maths.exp(1.0 - h)
  result.label = "impulse(" && trigger.label && ", " && apex.label && ")"

proc gaussian*(trigger, apex, deviation: Signal): Signal =
  let delta = trigger.timeSinceStart - apex
  result = maths.exp(-0.5 * delta * delta / deviation)
  result.label = "gaussian(" && trigger.label && ", " && apex.label && ", " && deviation.label && ")"

proc adsr*(trigger, a, d, s, r: Signal): Signal =
  let start = trigger.sampleAndHoldStart(signal.time)
  let stop = trigger.sampleAndHoldEnd(signal.time)

  proc f(ctx: Context): float =
    let time = ctx.time
    let start = start.f(ctx)
    let stop = stop.f(ctx)

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

proc line*(target, duration: Signal): Signal =
  let targetPrime = target.prime
  let targetChanged = target != targetPrime
  let value = targetChanged.sampleAndHold(targetPrime)
  let delta = targetChanged.timeSince
  proc f(ctx: Context): float =
    let delta  = delta.f(ctx)
    let value  = value.f(ctx)
    let duration = duration.f(ctx)
    let target = target.f(ctx)
    if delta <= 0.0:
      return value
    if delta >= duration:
      return target
    return value + (target - value) * delta / duration
  Signal(f: f, label: "line(" && target.label && ", " && duration.label && ")")

