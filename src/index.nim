import audio/[audio, context, signal]
import forth
import s00, s01, s02
import soundio
import std
import strutils

# Init audio system
let rss = newSoundSystem()
if rss.kind == Err:
  quit rss.msg
let ss = rss.value
ss.sio.flushEvents

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
for i in 0..MAX_BRANCHES-1:
  branches[i] = @[]

var currentBranch = 0
var line: string

while true:
  try:
    line = stdin.readLine
  except EOFError:
    break
  for cmd in line.strip.split:
    case cmd
    of "next":
      currentBranch = (currentBranch + 1) mod MAX_BRANCHES
    of "prev":
      currentBranch = (currentBranch - 1 + MAX_BRANCHES) mod MAX_BRANCHES
    else:
      branches[currentBranch].execute(cmd)
  let b = branches[currentBranch]
  dac.signal = if b.len > 0: b[high(b)] else: silence

