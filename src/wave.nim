import audio/audio
import drawille
import math
import osproc
import soundio
import std
import strutils

proc wave*(stream: OutStream, step: int = 1) =
  let monitor = stream.monitor
  let channelCount = stream.stream.layout.channelCount

  let width = "tput cols".execProcess.strip.parseInt
  let height = 8
  let w = width * 2
  let h = height * 4

  if channelCount * step * w > monitor.capacity:
    echo "step is too big"
    return

  var c = newCanvas(width, height)
  var ys = newSeq[float](w)
  var yMin = +Inf
  var yMax = -Inf

  for i in 0..<w:
    let ptrSample = cast[ptr float](monitor.read_ptr)
    let sample = ptrSample[]
    ys[i] = sample
    yMin = yMin.min(sample)
    yMax = yMax.max(sample)
    monitor.advance_read_ptr(cint(step * channelCount * float.sizeof))

  let project = linlin(yMin, yMax, (h-1).toFloat, 0)
  for i in 0..<w:
    c.toggle(i, max(0, min(h-1, ys[i].project.toInt)))

  echo "▲ ", yMax.round(3)
  echo c
  echo "▼ ", yMin.round(3)
   
  # ANSI codes to go clear the area we use for our drawing, might be useful for animation
  # echo "\e[A\e[K".repeat(height+2)

