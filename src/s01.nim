import audio/[context, signal]
import math
import soundio

proc saw*(freq: Signal, phase0: Signal = 0): Signal =
  let project = linlin(0, 1, -1, 1)
  var phases: array[SOUNDIO_MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let i = ctx.channel
    phases[i] = (phases[i] + freq.f(ctx) / ctx.sampleRate.toFloat).mod(1.0) 
    project((phase0.f(ctx) + phases[i]).mod(1.0))
  Signal(f: f)

proc triangle*(phase: Signal): Signal =
  proc f(ctx: Context): float =
    let x = 2.0 * phase.f(ctx)
    return if x > 0: 1.0 - x else: 1.0 + x
  Signal(f: f)

proc tri*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).triangle

proc rectangle*(phase: Signal, width: Signal): Signal =
  let p = linlin(-1, 1, 0, 1)
  proc f(ctx: Context): float =
    if p(phase.f(ctx)) <= p(width.f(ctx)):
      return 1.0
    else:
      return -1.0
  Signal(f: f)

proc pulse*(freq: Signal, width: Signal = 0.5, phase0: Signal = 0): Signal =
  freq.saw(phase0).rectangle(width)

let circle* = linlin(-1, 1, -PI, PI).toSignal

proc sin*(phase: Signal): Signal = 
  Signal(f: proc(ctx: Context): float = sin(TWOPI * phase.f(ctx)))

proc cos*(phase: Signal): Signal = 
  Signal(f: proc(ctx: Context): float = cos(TWOPI * phase.f(ctx)))

proc tan*(phase: Signal): Signal = 
  Signal(f: proc(ctx: Context): float = tan(TWOPI * phase.f(ctx)))

proc sinh*(phase: Signal): Signal = 
  Signal(f: proc(ctx: Context): float = sinh(TWOPI * phase.f(ctx)))

proc cosh*(phase: Signal): Signal = 
  Signal(f: proc(ctx: Context): float = cosh(TWOPI * phase.f(ctx)))

proc tanh*(phase: Signal): Signal = 
  Signal(f: proc(ctx: Context): float = tanh(TWOPI * phase.f(ctx)))

proc sine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).sin
proc cosine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).cos
proc tangent*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).tan
proc hsine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).sinh
proc hcosine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).cosh
proc htangent*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).tanh


