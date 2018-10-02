import audio/[context, signal]
import environment
import math

proc sampleReader*(indexer: Signal, sampler: Sampler): Signal =
  let size = sampler.table.len div MAX_CHANNELS
  proc f(ctx: Context): float =
    let z = (indexer.f(ctx) * ctx.sampleRate.toFloat).splitDecimal
    let i = z[0].toInt
    let k = z[1]
    return (1.0 - k) * sampler.table[(i mod size) * MAX_CHANNELS + ctx.channel] +
      k * sampler.table[((i + 1) mod size) * MAX_CHANNELS + ctx.channel]
  Signal(f: f)
