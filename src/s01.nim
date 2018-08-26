import audio/[context, signal]
import math
import soundio
import std

proc saw*(freq: Signal, phase0: Signal = 0): Signal =
  var phases: array[SOUNDIO_MAX_CHANNELS, float]
  var sampleNumbers: array[SOUNDIO_MAX_CHANNELS, int]
  for i in 0..<SOUNDIO_MAX_CHANNELS:
    phases[i] = 0.0
    sampleNumbers[i] = 0
  proc f(ctx: Context): float =
    let i = ctx.channel
    if ctx.sampleNumber > sampleNumbers[i]:
      phases[i] = (phases[i] + 2.0 * freq.f(ctx) / ctx.sampleRate.toFloat).mod(2.0)
      sampleNumbers[i] = ctx.sampleNumber
      let p0 = phase0.f(ctx) + 1.0
      return (p0 + phases[i]).mod(2.0) - 1.0
    else:
      return phases[i]
  Signal(f: f, label: "saw(" && freq.label && ", " && phase0.label && ")")

proc triangle*(phase: Signal): Signal =
  proc f(ctx: Context): float =
    let x = 2.0 * phase.f(ctx)
    return if x > 0: 1.0 - x else: 1.0 + x
  Signal(f: f, label: "triangle(" && phase.label && ")")

proc tri*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).triangle

proc rectangle*(phase: Signal, width: Signal): Signal =
  let p = linlin(-1, 1, 0, 1)
  proc f(ctx: Context): float =
    if p(phase.f(ctx)) <= width.f(ctx):
      return 1.0
    else:
      return -1.0
  Signal(f: f, label: "rectangle(" && phase.label && ", " && width.label && ")")

proc pulse*(freq: Signal, width: Signal = 0.5, phase0: Signal = 0): Signal =
  freq.saw(phase0).rectangle(width)

let circle* = linlin(-1, 1, -PI, PI).toSignal("circle")

proc sin*(phase: Signal): Signal = 
  Signal(
    f: proc(ctx: Context): float = sin(PI * phase.f(ctx)),
    label: "sin(" && phase.label && ")"
  )

proc cos*(phase: Signal): Signal = 
  Signal(
    f: proc(ctx: Context): float = cos(PI * phase.f(ctx)),
    label: "cos(" && phase.label && ")"
  )

proc tan*(phase: Signal): Signal = 
  Signal(
    f: proc(ctx: Context): float = tan(PI * phase.f(ctx)),
    label: "tan(" && phase.label && ")"
  )

proc sinh*(phase: Signal): Signal = 
  Signal(
    f: proc(ctx: Context): float = sinh(PI * phase.f(ctx)),
    label: "sinh(" && phase.label && ")"
  )

proc cosh*(phase: Signal): Signal = 
  Signal(
    f: proc(ctx: Context): float = cosh(PI * phase.f(ctx)),
    label: "cosh(" && phase.label && ")"
  )

proc tanh*(phase: Signal): Signal = 
  Signal(
    f: proc(ctx: Context): float = tanh(PI * phase.f(ctx)),
    label: "tanh(" && phase.label && ")"
  )

proc sine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).sin
proc cosine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).cos
proc tangent*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).tan
proc hsine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).sinh
proc hcosine*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).cosh
proc htangent*(freq: Signal, phase0: Signal = 0): Signal = freq.saw(phase0).tanh

proc clausen*(phase: Signal, n: int = 100): Signal =
  proc f(ctx: Context): float =
    result = 0
    let phi = PI * phase.f(ctx)
    for i in 1..n:
      let k = i.toFloat
      result += sin(k*phi)/(k*k)
  Signal(f: f,  label: "clausen(" && phase.label && ")")
