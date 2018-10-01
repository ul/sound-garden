import audio/[context, signal]
import basics
import math
import maths
import soundio
import std

proc delaySamples*(x, delay: Signal, maxDelay: int): Signal =
  # NOTE +1 because interpolation looks for the next sample
  let maxDelay = (maxDelay + 1).nextPowerOfTwo
  let mask = maxDelay - 1
  var buffer = newSeq[float](maxDelay * MAX_CHANNELS)
  proc f(ctx: Context): float =
    let z = delay.f(ctx).splitDecimal
    let delay = z[0].toInt
    let k = z[1]
    if ctx.sampleNumber > delay:
      let i = ctx.sampleNumber - delay
      let a = buffer[(  i      and mask ) * MAX_CHANNELS + ctx.channel]
      let b = buffer[( (i - 1) and mask ) * MAX_CHANNELS + ctx.channel]
      result = (1 - k) * a + k * b
    buffer[( ctx.sampleNumber and mask ) * MAX_CHANNELS + ctx.channel] = x.f(ctx)
  Signal(f: f) # mult?

proc delay*(x, delayTime: Signal, maxDelay: int): Signal = delaySamples(x, delayTime * sampleRate, maxDelay)

proc smoothDelaySamples*(x, dSamples: Signal; crossfade, maxDelay: int): Signal =
  let dSamplesPrime = dSamples.prime
  let trigger = dSamples != dSamplesPrime
  let dSamplesPrev = trigger.sampleAndHold(dSamplesPrime) 
  let delayStart = trigger.sampleAndHold(sampleNumber)
  let delta = sampleNumber - delayStart
  let k = 1.0.min(delta / crossfade)
  result = k * x.delaySamples(dSamples, maxDelay) + (1 - k) * x.delaySamples(dSamplesPrev, maxDelay)

proc smoothDelay*(x, delayTime: Signal; crossfade, maxDelay: int): Signal = smoothDelaySamples(x, delayTime * sampleRate, crossfade, maxDelay)
