import audio/[context, signal]
import math
import soundio
import std

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
