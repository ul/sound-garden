import audio/[audio, context, signal]
import basics
import math
import soundio
import std
import tables

const MAX_STREAMS* = 8

type
  Sampler*     = ref object
    table*       : seq[float]
  Environment* = ref object
    channelCount*: int
    head*        : int
    oscVariables*: TableRef[string, Box[float]]
    samplers*    : TableRef[string, Sampler]
    stacks*      : array[MAX_STREAMS, seq[Signal]]
    streams*     : array[MAX_STREAMS, IOStream]
    variables*   : TableRef[string, Signal]

proc currentStream*(env: Environment): IOStream = env.streams[env.head]
proc currentStack*(env: Environment): var seq[Signal] = env.stacks[env.head]

# TODO prefer Result[Environment] over quit
proc init*(): Environment =
  result = Environment(
    variables: newTable[string, Signal](),
    samplers: newTable[string, Sampler](),
    oscVariables: newTable[string, Box[float]]()
  )

  # init audio system
  let rss = newSoundSystem()
  if rss.kind == Err:
    quit rss.msg
  let ss = rss.value

  # pre-set variables for quick integration with OSC
  for k in 'a'..'z':
    result.variables[$k] = silence
    result.oscVariables[$k] = box(0.0)

  for i in 0..<MAX_STREAMS:
    let ros = ss.newIOStream
    if ros.kind == Err:
      quit ros.msg
    let dac = ros.value
    result.streams[i] = dac
    result.stacks[i] = @[]
    if i == 0:
      result.channelCount = dac.outStream.layout.channelCount
      echo "Sample Rate:\t", dac.outStream.sampleRate
      echo "Channels:\t", result.channelCount
      echo "Input Latency:\t", (1000.0 * dac.inStream.softwareLatency).round(1), " ms"
      echo "Output Latency:\t", (1000.0 * dac.outStream.softwareLatency).round(1), " ms"

