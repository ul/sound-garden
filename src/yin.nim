import audio/[context, signal]
import std

proc parabolicInterpolation(buffer: var seq[float], x1, size, offset: int): float {.inline.} =
  result = x1.toFloat
  let x0 = x1 - 1
  let x2 = x1 + 1
  let s0 = buffer[x0 + offset]
  let s1 = buffer[x1 + offset]
  let s2 = buffer[x2 + offset]
  let d = 2.0 * s1 - s2 - s0
  let delta = s2 - s0
  if d != 0.0:
    result += delta / (2.0 * d)

# NOTE window MUST be power of two!
proc pitch*(x: Signal, window: int = 1024, threshold: float = 0.2): Signal =
  let mask = window - 1
  let size = window div 2
  var samples = newSeq[float](MAX_CHANNELS * window)
  var buffer = newSeq[float](MAX_CHANNELS * size)
  var pitches: array[MAX_CHANNELS, float]

  proc f(ctx: Context): float =
    let i = ctx.channel
    let samplesOffset = i * window
    let offset = i * size
    # TODO implement buffer overlap for lower latency
    if (ctx.sampleNumber and mask) == 0:
      # difference
      for tau in 0..<size:
        buffer[tau + offset] = 0.0
      for tau in 1..<size:
        for index in 0..<size:
          let delta = samples[index + samplesOffset]  - samples[index + tau + samplesOffset]
          buffer[tau + offset] += delta * delta
      # cumulative mean normalized difference
      buffer[0 + offset] = 1.0
      var runningSum = 0.0
      for tau in 1..<size:
        runningSum += buffer[tau + offset]
        buffer[tau + offset] *= tau.toFloat / runningSum
      # absolute threshold
      var tau = 2
      while tau < size:
        if buffer[tau + offset] < threshold:
          while (tau + 1 < size) and (buffer[tau + 1 + offset] < buffer[tau + offset]):
            tau += 1
          break
        tau += 1
      if not ((tau == size) or (buffer[tau + offset] >= threshold)):
        pitches[i] = ctx.sampleRateFloat / parabolicInterpolation(buffer, tau, size, offset)
      else:
        pitches[i] = 0.0

    samples[(ctx.sampleNumber and mask) + samplesOffset]  = x.f(ctx)
    return pitches[i]
  Signal(f: f, label: "pitch(" && x.label && ")")
