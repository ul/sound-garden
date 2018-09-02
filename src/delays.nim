import audio/[context, signal]
import math
import maths
import soundio
import std

proc delaySamples*(x, delay: Signal, maxDelay: int): Signal =
  var buffer = newSeq[float](maxDelay * SOUNDIO_MAX_CHANNELS + 1)
  proc f(ctx: Context): float =
    let channelOffset = maxDelay * ctx.channel
    let z = delay.f(ctx).splitDecimal
    let delay = z[0].toInt
    let k = z[1]
    if ctx.sampleNumber > delay:
      let i = ctx.sampleNumber - delay
      let a = buffer[ i      mod maxDelay + channelOffset]
      let b = buffer[(i - 1) mod maxDelay + channelOffset]
      result = (1 - k) * a + k * b
    buffer[ctx.sampleNumber mod maxDelay + channelOffset] = x.f(ctx)
  Signal(f: f)

proc delay*(x, delayTime: Signal, maxDelay: int): Signal = delaySamples(x, delayTime * sampleRate, maxDelay)
