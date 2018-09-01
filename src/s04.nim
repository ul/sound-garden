import audio/[context, signal]
import math
import soundio
import std
import s03

proc feedback*(input, delay, fb: Signal): Signal =
  const bufferLen = 5 * 48000 # max delay 5 seconds @ 48000 sample rate
  var buffer: array[bufferLen * SOUNDIO_MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let delaySamples = (delay.f(ctx) * ctx.sampleRate.toFloat).round.toInt
    let channelOffset = ctx.channel * bufferLen
    let delayOffset = (ctx.sampleNumber - delaySamples + bufferLen) mod bufferLen + channelOffset
    result = buffer[delayOffset] * fb.f(ctx) + input.f(ctx)
    buffer[channelOffset + ctx.sampleNumber.mod(bufferLen)] = result
  Signal(
    f: f,
    label: "feedback(" && input.label && ", " && delay.label && ", " && fb.label && ")"
  ).mult

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

proc project*(x, c, d: Signal): Signal =
  const a = -1.0
  const b = 1.0
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let c = c.f(ctx)
    let d = d.f(ctx)
    return (d - c) * (x - a) / (b - a) + c
  Signal(f: f, label: "range(" && x.label && ", " && c.label && ", " && d.label && ")")
