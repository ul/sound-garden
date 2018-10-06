import audio/[context, signal]
import math
import maths
import std

proc metro*(freq: Signal): Signal =
  var lastTrigger: array[MAX_CHANNELS, int]
  proc f(ctx: Context): float =
    let i = ctx.channel
    let delta = (ctx.sampleRateFloat / freq.f(ctx)).toInt
    if delta <= ctx.sampleNumber - lastTrigger[i]:
      lastTrigger[i] = ctx.sampleNumber
      return 1.0
  Signal(f: f, label: "metro(" && freq.label && ")").mult

proc dmetro*(dt: Signal): Signal =
  var lastTrigger: array[MAX_CHANNELS, int]
  proc f(ctx: Context): float =
    let i = ctx.channel
    let delta = (ctx.sampleRateFloat * dt.f(ctx)).toInt
    if delta <= ctx.sampleNumber - lastTrigger[i]:
      lastTrigger[i] = ctx.sampleNumber
      return 1.0
  Signal(f: f, label: "dmetro(" && dt.label && ")").mult

proc metroHold*(freq: Signal): Signal =
  var lastTrigger: array[MAX_CHANNELS, int]
  var freqs: array[MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let i = ctx.channel
    let freq = freq.f(ctx)
    if freqs[i] == 0.0:
      freqs[i] = freq
    let delta = (ctx.sampleRateFloat / freqs[i]).toInt
    if delta <= ctx.sampleNumber - lastTrigger[i]:
      lastTrigger[i] = ctx.sampleNumber
      freqs[i] = freq
      return 1.0
  Signal(f: f, label: "metroHold(" && freq.label && ")").mult

proc dmetroHold*(dt: Signal): Signal =
  var lastTrigger: array[MAX_CHANNELS, int]
  var periods: array[MAX_CHANNELS, float]
  proc f(ctx: Context): float =
    let i = ctx.channel
    let dt = dt.f(ctx)
    if periods[i] == 0.0:
      periods[i] = dt
    let delta = (ctx.sampleRateFloat * periods[i]).toInt
    if delta <= ctx.sampleNumber - lastTrigger[i]:
      lastTrigger[i] = ctx.sampleNumber
      periods[i] = dt
      return 1.0
  Signal(f: f, label: "dmetroHold(" && dt.label && ")").mult

