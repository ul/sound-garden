import context
import math
import soundio
import std

type
  Signal* = ref object
    f*: proc(ctx: Context): float
    label*: string
  FF1 = proc(x: float): float
  FF2 = proc(x, y: float): float
  FF3 = proc(x, y, z: float): float
  Function0 = proc(): Signal
  Function1 = proc(x: Signal): Signal
  Function2 = proc(x, y: Signal): Signal
  Function3 = proc(x, y, z: Signal): Signal
  Function4 = proc(x, y, z, a: Signal): Signal

converter toSignal*(x: float): Signal =
  proc f(ctx: Context): float = x
  Signal(f: f, label: $x)

converter toSignal*(x: int): Signal = x.toFloat.toSignal

converter toSignal*(x: Box[float]): Signal =
  proc f(ctx: Context): float = x.get
  Signal(f: f, label: "Box")

converter toSignal*(x: Box[int]): Signal =
  proc f(ctx: Context): float = x.get.toFloat
  Signal(f: f, label: "Box")

proc toSignal*(map: FF1, label: string = "f"): Function1 =
  proc function(x: Signal): Signal =
    proc f(ctx: Context): float = map(x.f(ctx))
    Signal(f: f, label: label && "(" && x.label && ")")
  return function

proc toSignal*(map: FF2, label: string = "f"): Function2 =
  proc function(x, y: Signal): Signal =
    proc f(ctx: Context): float = map(x.f(ctx), y.f(ctx))
    Signal(f: f, label: label && "(" && x.label && ", " && y.label && ")")
  return function

proc toSignal*(map: FF3, label: string = "f"): Function3 =
  proc function(x, y, z: Signal): Signal =
    proc f(ctx: Context): float = map(x.f(ctx), y.f(ctx), z.f(ctx))
    Signal(f: f, label: label && "(" && x.label && ", " && y.label && ", " && z.label && ")")
  return function

proc channel*(x: Signal, i: int = 0): Signal =
  var sample: float
  proc f(ctx: Context): float =
    if ctx.channel == i:
      sample = x.f(ctx)
    sample
  Signal(f: f, label: "channel " & $i & " of " && x.label)

# TODO review concept and implementation of lastSample
# meanwhile please don't use it actively to avoid huge refactor
proc mult*(x: Signal): Signal =
  var samples: array[SOUNDIO_MAX_CHANNELS, float]
  var sampleNumbers: array[SOUNDIO_MAX_CHANNELS, int]
  proc f(ctx: Context): float =
    let i = ctx.channel
    if ctx.sampleNumber > sampleNumbers[i]:
      sampleNumbers[i] = ctx.sampleNumber
      let lastSample = ctx.lastSample
      ctx.lastSample = samples[i]
      samples[i] = x.f(ctx)
      ctx.lastSample = lastSample
    return samples[i]
  Signal(f: f, label: x.label)

proc prime*(x: Signal): Signal =
  var samples: array[SOUNDIO_MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let i = ctx.channel
    result = samples[i]
    samples[i] = x.f(ctx)
  Signal(f: f, label: "prime(" && x.label && ")").mult

proc recur*(function: Function1): Function0 =
  proc recursiveFunction(): Signal =
    let feedbackProxy = Signal()
    result = function(feedbackProxy)
    let actualFeedback = result.prime
    proc f(ctx: Context): float = actualFeedback.f(ctx)
    feedbackProxy.f = f
  return recursiveFunction

proc recur*(function: Function2): Function1 =
  proc recursiveFunction(x: Signal): Signal =
    let feedbackProxy = Signal()
    result = function(feedbackProxy, x)
    let actualFeedback = result.prime
    proc f(ctx: Context): float = actualFeedback.f(ctx)
    feedbackProxy.f = f
  return recursiveFunction

proc recur*(function: Function3): Function2 =
  proc recursiveFunction(x, y: Signal): Signal =
    let feedbackProxy = Signal()
    result = function(feedbackProxy, x, y)
    let actualFeedback = result.prime
    proc f(ctx: Context): float = actualFeedback.f(ctx)
    feedbackProxy.f = f
  return recursiveFunction

proc recur*(function: Function4): Function3 =
  proc recursiveFunction(x, y, z: Signal): Signal =
    let feedbackProxy = Signal()
    result = function(feedbackProxy, x, y, z)
    let actualFeedback = result.prime
    proc f(ctx: Context): float = actualFeedback.f(ctx)
    feedbackProxy.f = f
  return recursiveFunction

let sampleNumber* = Signal(f: proc(ctx: Context): float = ctx.sampleNumber.toFloat, label: "sampleNumber")
let sampleRate* = Signal(f: proc(ctx: Context): float = ctx.sampleRate.toFloat, label: "sampleRate")
let sampleAngularPeriod* = Signal(f: proc(ctx: Context): float = ctx.sampleAngularPeriod, label: "sampleAngularPeriod")
