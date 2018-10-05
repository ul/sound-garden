import audio/[context, signal]
import basics
import envelopes
import environment
import math
import maths
import oscillators
import samplers
import triggers

# 8 m n 0 40 r sh .25 w unit 40 * + rt:z  16 m .03125 .0001 gaussian *
# <jump trigger> n 0 <table length> r sh <playback speed> w unit <table length> * + rt:<table name>
# <grain trigger> apex deviation gaussian * (or another envelope)

const FWTM = 0.125 / ln(10.0) 

proc grain*(sampler: Sampler; period, accel, width: Signal): Signal =
  let trig = period.dmetro
  let dur = sampler.table.len div MAX_CHANNELS
  let index = (accel / dur).saw.unit * dur
  let offset = trig.sampleAndHoldStart(whiteNoise.range(0, dur))
  let x = (index + offset).sampleReader(sampler)
  let envelope = trig.gaussian(0.5 * period, width * width * FWTM)
  return x * envelope

