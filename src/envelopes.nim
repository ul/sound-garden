import audio/[context, signal]
import basics
import math
import maths
import soundio
import std

# NOTE apex is relative to start and is in seconds
proc impulse*(trigger, apex: Signal): Signal =
  let startSample = (trigger > 0.0).sampleAndHold(sampleNumber)
  let h = (sampleNumber - startSample) / (apex * sampleRate)
  result = h * maths.exp(1.0 - h)
  result.label = "impulse(" && trigger.label && ", " && apex.label && ")"

