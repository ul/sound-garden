import audio/[context, signal]
import basics
import environment
import math

proc sampleReader*(indexer: Signal, sampler: Sampler): Signal =
  let size = sampler.table.len div MAX_CHANNELS
  proc f(ctx: Context): float =
    let z = (indexer.f(ctx) * ctx.sampleRateFloat).splitDecimal
    let i = z[0].toInt
    let k = z[1]
    return (1.0 - k) * sampler.table[(i mod size) * MAX_CHANNELS + ctx.channel] +
      k * sampler.table[((i + 1) mod size) * MAX_CHANNELS + ctx.channel]
  Signal(f: f)

proc sampleWriter*(t: Sampler; trigger, x: Signal): Signal =
  let size = t.table.len div MAX_CHANNELS
  let delta = trigger.sampleSinceStart
  proc f(ctx: Context): float =
    result = x.f(ctx)
    let n = delta.f(ctx).toInt
    if n < size:
      t.table[n * MAX_CHANNELS + ctx.channel] = result
  Signal(f: f)
