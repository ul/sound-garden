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

proc smoothDelaySamples*(x, delay: Signal, crossfade, maxDelay: int): Signal =
  var buffer = newSeq[float](maxDelay * SOUNDIO_MAX_CHANNELS + 1)
  var delayValues = newSeq[float](crossfade * SOUNDIO_MAX_CHANNELS)
  # this is start sample for current delay value and end sample for previous ones
  var delayMarks = newSeq[int](crossfade * SOUNDIO_MAX_CHANNELS)
  var cursors = newSeq[int](crossfade * SOUNDIO_MAX_CHANNELS)
  let pdelay = delay.prime
  proc ff(ctx: Context, delay: float): float =
    let channelOffset = maxDelay * ctx.channel
    let z = delay.splitDecimal
    let delay = z[0].toInt
    let k = z[1]
    if ctx.sampleNumber > delay:
      let i = ctx.sampleNumber - delay
      let a = buffer[ i      mod maxDelay + channelOffset]
      let b = buffer[(i - 1) mod maxDelay + channelOffset]
      result = (1 - k) * a + k * b
  proc f(ctx: Context): float =
    let delay = delay.f(ctx)
    let pdelay = pdelay.f(ctx)
    let ch = ctx.channel
    let channelOffset = ch * crossfade
    if pdelay != delay:
      # set end mark for previous delay
      delayMarks[cursors[ch] + channelOffset] = ctx.sampleNumber
      # and put value and start mark for the new current one
      cursors[ch] = (cursors[ch] + 1) mod crossfade
      delayValues[cursors[ch] + channelOffset] = delay
      delayMarks[cursors[ch] + channelOffset] = ctx.sampleNumber
    # current delay
    var mark = delayMarks[cursors[ch] + channelOffset]
    let delta = ctx.sampleNumber - mark
    var k = (delta.toFloat / crossfade.toFloat).min(1.0)
    result = k * ff(ctx, delay)
    # past delays
    var base = crossfade - delta
    k = 1.0 - k
    if base > 0:
      for i in 1..<crossfade:
        let j = (cursors[ch] - i + crossfade) mod crossfade
        let nextMark = delayMarks[j + channelOffset]
        let delta = mark - nextMark
        if delta >= base:
          break
        let a = delta.toFloat / base.toFloat
        result += k * (1.0 - a) * ff(ctx, delayValues[j + channelOffset])
        base -= delta
        mark = nextMark
        k *= a
    buffer[ctx.sampleNumber mod maxDelay + ch * maxDelay] = x.f(ctx)
  Signal(f: f)

proc smoothDelay*(x, delayTime: Signal; crossfade, maxDelay: int): Signal = smoothDelaySamples(x, delayTime * sampleRate, crossfade, maxDelay)
