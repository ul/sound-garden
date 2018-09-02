import audio/[audio, context, signal]
import drawille
import forth
import math
import osproc
import soundio
import std
import strutils

# Init audio system
let rss = newSoundSystem()
if rss.kind == Err:
  quit rss.msg
let ss = rss.value

# Create default output stream with write callback ready to accept signal via userdata
let ros = ss.newOutStream
if ros.kind == Err:
  quit ros.msg
let dac = ros.value
# TODO ensure that format is float32ne or support conversion
echo "Format:\t\t", dac.stream.format
echo "Sample Rate:\t", dac.stream.sampleRate
echo "Channels:\t", dac.stream.layout.channelCount
echo "Latency:\t", (1000.0 * dac.stream.softwareLatency).round(1), " ms"

proc linlin*(a, b, c, d: float): proc(x: float): float =
  let k = (d - c) / (b - a)
  proc f(x: float): float = k * (x - a) + c
  return f

proc wave*(step: int = 1) =
  let monitor = dac.monitor
  let channelCount = dac.stream.layout.channelCount

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

const MAX_BRANCHES = 8
var branches: array[MAX_BRANCHES, seq[Signal]]
for i in 0..<MAX_BRANCHES:
  branches[i] = @[]

var currentBranch = 0
var line: string

while true:
  stdout.write "> "
  try:
    line = stdin.readLine
  except EOFError:
    break
  for cmd in line.strip.split:
    let c = cmd.split(":")
    case c[0]
    of "wave":
      var step = 1
      if c.len > 1:
        step = c[1].parseInt
      step.wave
    of "next":
      currentBranch = (currentBranch + 1) mod MAX_BRANCHES
    of "prev":
      currentBranch = (currentBranch - 1 + MAX_BRANCHES) mod MAX_BRANCHES
    else:
      branches[currentBranch].execute(c[0])
  let b = branches[currentBranch]
  dac.signal = if b.len > 0: b[high(b)] else: 0

