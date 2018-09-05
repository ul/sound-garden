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

const MAX_STREAMS = 8
var streams: array[MAX_STREAMS, OutStream]
var stacks: array[MAX_STREAMS, seq[Signal]]
var currentStack = 0

for i in 0..<MAX_STREAMS:
  let ros = ss.newOutStream
  if ros.kind == Err:
    quit ros.msg
  let dac = ros.value
  streams[i] = dac
  stacks[i] = @[]
  # TODO ensure that format is float32ne or support conversion
  if i == 0:
    echo "Format:\t\t", dac.stream.format
    echo "Sample Rate:\t", dac.stream.sampleRate
    echo "Channels:\t", dac.stream.layout.channelCount
    echo "Latency:\t", (1000.0 * dac.stream.softwareLatency).round(1), " ms"

let silence = 0.0.toSignal

proc linlin*(a, b, c, d: float): proc(x: float): float =
  let k = (d - c) / (b - a)
  proc f(x: float): float = k * (x - a) + c
  return f

proc wave*(step: int = 1) =
  let monitor = streams[currentStack].monitor
  let channelCount = streams[currentStack].stream.layout.channelCount

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

var line: string

while true:
  stdout.write currentStack, " > "
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
      currentStack = (currentStack + 1) mod MAX_STREAMS
    of "prev":
      currentStack = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
    of "mv>":
      if stacks[currentStack].len > 0:
        let i = (currentStack + 1) mod MAX_STREAMS
        stacks[i] &= stacks[currentStack].pop
    of "<mv":
      if stacks[currentStack].len > 0:
        let i = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
        stacks[i] &= stacks[currentStack].pop
    of "mv<":
      let i = (currentStack + 1) mod MAX_STREAMS
      if stacks[i].len > 0:
        stacks[currentStack] &= stacks[i].pop
    of ">mv":
      let i = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
      if stacks[i].len > 0:
        stacks[currentStack] &= stacks[i].pop
    of "cp>":
      if stacks[currentStack].len > 0:
        let i = (currentStack + 1) mod MAX_STREAMS
        stacks[i] &= stacks[currentStack][stacks[currentStack].high]
    of "<cp":
      if stacks[currentStack].len > 0:
        let i = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
        stacks[i] &= stacks[currentStack][stacks[currentStack].high]
    of "cp<":
      let i = (currentStack + 1) mod MAX_STREAMS
      if stacks[i].len > 0:
        stacks[currentStack] &= stacks[i][stacks[i].high]
    of ">cp":
      let i = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
      if stacks[i].len > 0:
        stacks[currentStack] &= stacks[i][stacks[i].high]
    else:
      stacks[currentStack].execute(c[0])
  for i in 0..<MAX_STREAMS:
    let s = stacks[i]
    streams[i].signal = if s.len > 0: s[high(s)] else: silence

