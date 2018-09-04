import audio/[context, signal]
import math
import maths
import soundio
import std

proc metro*(freq: Signal): Signal =
  var lastTrigger: array[SOUNDIO_MAX_CHANNELS, int]
  proc f(ctx: Context): float =
    let i = ctx.channel
    let delta = (ctx.sampleRate.toFloat / freq.f(ctx)).toInt
    if delta <= ctx.sampleNumber - lastTrigger[i]:
      lastTrigger[i] = ctx.sampleNumber
      return 1.0
  Signal(f: f, label: "metro(" && freq.label && ")").mult

