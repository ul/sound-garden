import audio/[context, signal]
import basics
import math
import maths
import soundio
import std

proc saw*(freq: Signal, phase0: Signal = 0): Signal =
  var phases: array[MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let i = ctx.channel
    phases[i] = (phases[i] + 2.0 * freq.f(ctx) / ctx.sampleRate.toFloat).mod(2.0)
    let p0 = phase0.f(ctx) + 1.0
    return (p0 + phases[i]).mod(2.0) - 1.0
  Signal(f: f, label: "saw(" && freq.label && ", " && phase0.label && ")").mult

proc triangle*(phase: Signal): Signal =
  proc f(ctx: Context): float =
    let x = 2.0 * phase.f(ctx)
    return if x > 0: 1.0 - x else: 1.0 + x
  Signal(f: f, label: "triangle(" && phase.label && ")")

proc tri*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).triangle

proc rectangle*(phase: Signal, width: Signal = 0.5): Signal =
  let p = phase.unit
  proc f(ctx: Context): float =
    if p.f(ctx) <= width.f(ctx):
      return 1.0
    else:
      return -1.0
  Signal(f: f, label: "rectangle(" && phase.label && ", " && width.label && ")")

proc pulse*(freq: Signal, width: Signal = 0.5, phase0: Signal = 0): Signal =
  freq.saw(phase0).rectangle(width)

proc sine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).sin
proc cosine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).cos
proc tangent*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).tan
proc hsine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).sinh
proc hcosine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).cosh
proc htangent*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).tanh

