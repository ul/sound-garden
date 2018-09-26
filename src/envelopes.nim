import audio/[context, signal]
import basics
import math
import maths
import soundio
import std

proc holdStart(trigger: Signal): Signal = (trigger.prime <= 0.0 and trigger > 0.0).sampleAndHold(sampleNumber)
proc holdEnd(trigger: Signal): Signal = (trigger.prime > 0.0 and trigger <= 0.0).sampleAndHold(sampleNumber)

# NOTE apex is relative to start and is in seconds
proc impulse*(trigger, apex: Signal): Signal =
  let startSample = trigger.holdStart
  let h = (sampleNumber - startSample) / (apex * sampleRate)
  result = h * maths.exp(1.0 - h)
  result.label = "impulse(" && trigger.label && ", " && apex.label && ")"

proc gaussian*(trigger, apex, deviation: Signal): Signal =
  let startSample = trigger.holdStart
  let x = (sampleNumber - startSample) / sampleRate
  let delta = x - apex
  let ratio = delta / deviation
  result = maths.exp(-0.5 * ratio * ratio)
  result.label = "gaussian(" && trigger.label && ", " && apex.label && ", " && deviation.label && ")"

proc adsr*(trigger, a, d, s, r: Signal): Signal =
  let startSample = trigger.holdStart
  let endSample = trigger.holdEnd

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

proc line*(target, time: Signal): Signal =
  let time = time * sampleRate
  let targetPrime = target.prime
  let targetChanged = target != targetPrime
  let value = targetChanged.sampleAndHold(targetPrime)
  let delta = sampleNumber - targetChanged.sampleAndHold(sampleNumber)
  proc f(ctx: Context): float =
    let delta  = delta.f(ctx)
    let value  = value.f(ctx)
    let time   = time.f(ctx)
    let target = target.f(ctx)
    if delta <= 0.0:
      return value
    if delta >= time:
      return target
    return value + (target - value) * delta / time
  Signal(f: f, label: "line(" && target.label && ", " && time.label && ")")

