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
  var buffer = newSeq[float](maxDelay * SOUNDIO_MAX_CHANNELS)
  proc f(ctx: Context): float =
    let channelOffset = maxDelay * ctx.channel
    let z = delay.f(ctx).splitDecimal
    let delay = z[0].toInt
    let k = z[1]
    if ctx.sampleNumber > delay:
      let i = ctx.sampleNumber - delay
      let a = buffer[(  i      and mask ) + channelOffset]
      let b = buffer[( (i - 1) and mask ) + channelOffset]
      result = (1 - k) * a + k * b
    buffer[( ctx.sampleNumber and mask ) + channelOffset] = x.f(ctx)
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

# NOTE crossfade MUST be power of two!
proc smoothestDelaySamples*(x, delay: Signal, crossfade, maxDelay: int): Signal =
  # NOTE +1 because interpolation looks for the next sample
  let maxDelay = (maxDelay + 1).nextPowerOfTwo
  let mask = maxDelay - 1
  let xfadeMask = crossfade - 1
  var buffer = newSeq[float](maxDelay * SOUNDIO_MAX_CHANNELS)
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
      let a = buffer[(  i      and mask ) + channelOffset]
      let b = buffer[( (i - 1) and mask ) + channelOffset]
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
      cursors[ch] = (cursors[ch] + 1) and xfadeMask
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
        let j = (cursors[ch] - i + crossfade) and xfadeMask
        let nextMark = delayMarks[j + channelOffset]
        let delta = mark - nextMark
        if delta >= base:
          break
        let a = delta.toFloat / base.toFloat
        result += k * (1.0 - a) * ff(ctx, delayValues[j + channelOffset])
        base -= delta
        mark = nextMark
        k *= a
    buffer[( ctx.sampleNumber and mask ) + ch * maxDelay] = x.f(ctx)
  Signal(f: f) # mult?

proc smoothestDelay*(x, delayTime: Signal; crossfade, maxDelay: int): Signal = smoothDelaySamples(x, delayTime * sampleRate, crossfade, maxDelay)
