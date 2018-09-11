import audio/[audio, context, signal]
import basics
import forth
import math
import maths
import soundio
import std
import strutils
import tables
import lo/[lo, lo_serverthread, lo_types, lo_osc_types]
import wave

type
  Sampler = ref object
    table: seq[float]

var channelCount: int

let silence = 0.toSignal

# Init audio system
let rss = newSoundSystem()
if rss.kind == Err:
  quit rss.msg
let ss = rss.value

const MAX_STREAMS = 8
var streams: array[MAX_STREAMS, IOStream]
var stacks: array[MAX_STREAMS, seq[Signal]]
var currentStack = 0
var variables = newTable[string, Signal]()
var samplers = newTable[string, Sampler]()
var osc = newTable[string, Box[float]]()

# pre-set variables for quick integration with OSC
for k in 'a'..'z':
  variables[$k] = silence
  osc[$k] = box(0.0)

for i in 0..<MAX_STREAMS:
  let ros = ss.newIOStream
  if ros.kind == Err:
    quit ros.msg
  let dac = ros.value
  streams[i] = dac
  stacks[i] = @[]
  if i == 0:
    channelCount = dac.outStream.layout.channelCount
    echo "Sample Rate:\t", dac.outStream.sampleRate
    echo "Channels:\t", channelCount
    echo "Input Latency:\t", (1000.0 * dac.inStream.softwareLatency).round(1), " ms"
    echo "Output Latency:\t", (1000.0 * dac.outStream.softwareLatency).round(1), " ms"

proc interpret(line: string) =
  for cmd in line.splitWhitespace:
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
      else:
        echo "Nothing to move"
    of "<mv":
      if stacks[currentStack].len > 0:
        let i = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
        stacks[i] &= stacks[currentStack].pop
      else:
        echo "Nothing to move"
    of "mv<":
      let i = (currentStack + 1) mod MAX_STREAMS
      if stacks[i].len > 0:
        stacks[currentStack] &= stacks[i].pop
      else:
        echo "Nothing to move"
    of ">mv":
      let i = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
      if stacks[i].len > 0:
        stacks[currentStack] &= stacks[i].pop
      else:
        echo "Nothing to move"
    of "cp>":
      if stacks[currentStack].len > 0:
        let i = (currentStack + 1) mod MAX_STREAMS
        stacks[i] &= stacks[currentStack][stacks[currentStack].high]
      else:
        echo "Nothing to copy"
    of "<cp":
      if stacks[currentStack].len > 0:
        let i = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
        stacks[i] &= stacks[currentStack][stacks[currentStack].high]
      else:
        echo "Nothing to copy"
    of "cp<":
      let i = (currentStack + 1) mod MAX_STREAMS
      if stacks[i].len > 0:
        stacks[currentStack] &= stacks[i][stacks[i].high]
      else:
        echo "Nothing to copy"
    of ">cp":
      let i = (currentStack - 1 + MAX_STREAMS) mod MAX_STREAMS
      if stacks[i].len > 0:
        stacks[currentStack] &= stacks[i][stacks[i].high]
      else:
        echo "Nothing to copy"
    of "var", "box":
      if c.len > 1:
        if stacks[currentStack].len > 0:
          let key = c[1]
          variables[key] = stacks[currentStack].pop
          stacks[currentStack] &= Signal(
            f: proc(ctx: Context): float = variables[key].f(ctx),
            label: cmd
          )
        else:
          echo "Stack is empty"
      else:
        echo "Provide a key"
    of "set":
      if c.len > 1:
        if stacks[currentStack].len > 0:
          variables[c[1]] = stacks[currentStack].pop
        else:
          echo "Stack is empty"
      else:
        echo "Provide a key"
    of "get":
      if c.len > 1:
        let key = c[1]
        if variables.hasKey(key):
          stacks[currentStack] &= Signal(
            f: proc(ctx: Context): float = variables[key].f(ctx),
            label: "var:" & key
          )
        else:
          echo "Value is not set"
      else:
        echo "Provide a key"
    of "unbox":
      if c.len > 1:
        if variables.hasKey(c[1]):
          stacks[currentStack] &= variables[c[1]]
        else:
          echo "Value is not set"
      else:
        echo "Provide a key"
    of "osc":
      if c.len > 1:
        let key = c[1]
        if not osc.hasKey(key):
          osc[key] = box(0.0)
        let s = osc[key].toSignal
        s.label = cmd
        stacks[currentStack] &= s
      else:
        echo "Provide a key"
    of "wtable", "wt":
      if c.len > 2:
        if stacks[currentStack].len > 1:
          let key = c[1]
          let size = c[2].parseInt
          var t = Sampler(table: newSeq[float](size * channelCount))
          let x = stacks[currentStack].pop
          let trigger = stacks[currentStack].pop
          let delta = sampleNumber - trigger.sampleAndHold(sampleNumber)
          proc f(ctx: Context): float =
            result = x.f(ctx)
            let n = delta.f(ctx).toInt
            if n < size:
              t.table[n + ctx.channel * size] = result
          stacks[currentStack] &= Signal(f: f, label: trigger.label & " " & x.label & " " & cmd)
          samplers[key] = t
        else:
          echo "Stack is too short, but trigger and input signals are required"
      else:
        echo "Usage: wtable:<name>:<len>"
    of "rtable", "rt":
      if c.len > 1:
        if stacks[currentStack].len > 0:
          let key = c[1]
          if samplers.hasKey(key):
            let t = samplers[key]
            let size = t.table.len div channelCount
            let x = stacks[currentStack].pop
            proc f(ctx: Context): float =
              let z = (x.f(ctx) * ctx.sampleRate.toFloat).splitDecimal
              let i = z[0].toInt
              let k = z[1]
              let offset = ctx.channel * size
              return (1.0 - k) * t.table[(i mod size) + offset] + k * t.table[((i + 1) mod size) + offset]
            stacks[currentStack] &= Signal(f: f, label: x.label & " " & cmd)
          else:
            echo "Table is not found: ", key
        else:
          echo "Stack is empty, but indexing signal required"
      else:
        echo "Usage: rtable:<name>"
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
  let line: cstring = arg0.s.addr
  ($line).interpret

proc accxyz_handler(path: cstring; types: cstring; argv: ptr ptr lo_arg; argc: cint; msg: lo_message; user_data: pointer): cint {.cdecl.} =
  let argvi = cast[int](argv)
  let psz = pointer.sizeof
  let arg0 = cast[ptr lo_arg](argv[])
  let arg1 = cast[ptr lo_arg](cast[ptr ptr lo_arg](argvi + psz)[])
  let arg2 = cast[ptr lo_arg](cast[ptr ptr lo_arg](argvi + 2 * psz)[])
  # variables["x"] = arg0.f.toSignal
  # variables["y"] = arg1.f.toSignal
  # variables["z"] = arg2.f.toSignal
  osc["x"].set(arg0.f)
  osc["y"].set(arg1.f)
  osc["z"].set(arg2.f)

proc var_set_handler(path: cstring; types: cstring; argv: ptr ptr lo_arg; argc: cint; msg: lo_message; user_data: pointer): cint {.cdecl.} =
  var path = $path
  if not path.startsWith("/set/"):
    return 1
  path.removePrefix("/set/")
  let arg0 = cast[ptr lo_arg](argv[])
  # variables[path] = arg0.f.toSignal
  if not osc.hasKey(path):
    osc[path] = box(0.0)
  osc[path].set(arg0.f)


let oscServerThread = lo_server_thread_new("7770", error);
discard lo_server_thread_add_method(oscServerThread, "/interpret", "s", interpret_handler, nil);
discard lo_server_thread_add_method(oscServerThread, "/accxyz", "fff", accxyz_handler, nil);
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
