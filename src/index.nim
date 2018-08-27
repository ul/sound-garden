import audio/[audio, context, signal]
import drawille
import forth
import math
import osproc
import s00, s01, s02, s03
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
echo "Latency:\t", dac.stream.softwareLatency

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
      let width = "tput cols".execProcess.strip.parseInt
      let height = 8
      var c = newCanvas(width, height)
      var ctx = dac.context
      let s = dac.signal
      let project = linlin(-1, 1, 4.0*height.toFloat, 0)
      ctx.channel = 0
      # NOTE we still need to call signal for each sample in case it's not pure
      var sample: float
      for i in 0..<(width*2*step):
        sample = s.f(ctx)
        ctx.sampleNumber += 1
        if i mod step == 0:
          c.toggle(i div step, sample.project.toInt)
      echo c
      # ANSI codes to go clear the area we use for our drawing
      # echo "\e[A\e[K".repeat(height+2)
    of "next":
      currentBranch = (currentBranch + 1) mod MAX_BRANCHES
    of "prev":
      currentBranch = (currentBranch - 1 + MAX_BRANCHES) mod MAX_BRANCHES
    else:
      branches[currentBranch].execute(c[0])
  let b = branches[currentBranch]
  dac.signal = if b.len > 0: b[high(b)] else: silence

