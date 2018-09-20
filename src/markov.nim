import audio/[context, signal]
import basics
import math
import maths
import random
import std

proc markovSample*(x: Signal): Signal =
  const q = 8
  let n = (1 shl q) - 1
  let x = x.range(0, n).clip(0, n)
  let px = x.prime
  let y = Signal()
  let py = y.mult
  var network: array[MAX_CHANNELS shl (q * 2), int]
  proc f(ctx: Context): float =
    let offset = ctx.channel shl (q * 2)
    # record x transition
    let x = x.f(ctx).toInt 
    let px = px.f(ctx).toInt shl q 
    network[x + px + offset] += 1
    # generate markov sample
    let py = py.f(ctx).toInt shl q
    var sum = 0
    for s in 0..n:
      sum += network[s + py + offset]
    let r = rand(sum)
    sum = 0
    for s in 0..n:
      sum += network[s + py + offset]
      if sum >= r:
        return s.toFloat
  y.f = f
  result = y.project(0, n, -1, 1).mult
  result.label =  "markov(" && x.label && ")"

