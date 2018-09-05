import audio/[audio, context, signal]
import forth
import math
import soundio
import std
import strutils
import tables
import lo/[lo, lo_serverthread, lo_types, lo_osc_types]
import wave

let silence = 0.0.toSignal

# Init audio system
let rss = newSoundSystem()
if rss.kind == Err:
  quit rss.msg
let ss = rss.value

const MAX_STREAMS = 8
var streams: array[MAX_STREAMS, OutStream]
var stacks: array[MAX_STREAMS, seq[Signal]]
var currentStack = 0
var storage = newTable[string, Signal]()

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

proc interpret(line: string) =
  for cmd in line.strip.split:
    let c = cmd.split(":")
    case c[0]
    of "wave":
      var step = 1
      if c.len > 1:
        step = c[1].parseInt
      streams[currentStack].wave(step)
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
    of "var":
      if c.len > 1:
        if stacks[currentStack].len > 0:
          let key = c[1]
          storage[key] = stacks[currentStack].pop
          stacks[currentStack] &= Signal(
            f: proc(ctx: Context): float = storage[key].f(ctx),
            label: cmd
          )
        else:
          echo "Stack is too short"
      else:
        echo "Provide a key"
    of "set":
      if c.len > 1:
        if stacks[currentStack].len > 0:
          storage[c[1]] = stacks[currentStack].pop
        else:
          echo "Stack is too short"
      else:
        echo "Provide a key"
    of "get":
      if c.len > 1:
        if storage.hasKey(c[1]):
          stacks[currentStack] &= storage[c[1]]
        else:
          echo "Value is not set"
      else:
        echo "Provide a key"
    else:
      stacks[currentStack].execute(cmd)
  for i in 0..<MAX_STREAMS:
    let s = stacks[i]
    streams[i].signal = if s.len > 0: s[s.high] else: silence

### OSC
proc error(num: cint; msg: cstring; where: cstring) {.cdecl.} =
  echo "liblo server error ", num, " in path ", where, ": ", msg

proc interpret_handler(path: cstring; types: cstring; argv: ptr ptr lo_arg; argc: cint; msg: lo_message; user_data: pointer): cint {.cdecl.} =
  let arg0 = cast[ptr lo_arg](argv[])
  let line = $arg0.s
  line.interpret

proc var_set_handler(path: cstring; types: cstring; argv: ptr ptr lo_arg; argc: cint; msg: lo_message; user_data: pointer): cint {.cdecl.} =
  var path = $path
  if not path.startsWith("/set/"):
    return 1
  path.removePrefix("/set/") 
  let arg0 = cast[ptr lo_arg](argv[])
  storage[path] = arg0.f.toSignal

let oscServerThread = lo_server_thread_new("7770", error);
discard lo_server_thread_add_method(oscServerThread, "/interpret", "s", interpret_handler, nil);
discard lo_server_thread_add_method(oscServerThread, nil, "f", var_set_handler, nil);
discard lo_server_thread_start(oscServerThread)

### /OSC

while true:
  stdout.write "[", currentStack, "]> "
  try:
    stdin.readLine.interpret
  except EOFError:
    break

lo_server_thread_free(oscServerThread)
