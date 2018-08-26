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

var stack: seq[Signal] = @[]
while true:
  for cmd in stdin.readLine.strip.split:
    stack.execute(cmd)
  dac.signal = stack[high(stack)]

