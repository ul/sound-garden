import audio/[context, signal]
import basics
import math
import maths
import soundio
import std

# NOTE apex is relative to start and is in seconds
proc impulse*(start, apex: Signal): Signal =
  let startSample = start.sampleAndHold(sampleNumber)
  let h = max(0.0, sampleNumber - startSample) / (apex * sampleRate)
  result = h * maths.exp(1.0 - h)
  result.label = "impulse(" && start.label && ", " && apex.label && ")"

