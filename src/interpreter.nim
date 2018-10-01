import audio/[audio, context, signal]
import basics
import disk
import environment
import math
import maths
import std
import strutils
import tables
import wave
import words

proc interpret*(env: Environment, line: string) =
  for cmd in line.splitWhitespace:
    let c = cmd.split(":")
    case c[0]
    of "wave":
      when defined(windows):
        echo "wave is not supported on Windows"
      else:
        var step = 1
        if c.len > 1:
          step = c[1].parseInt
        env.currentStream.wave(step)
    of "next":
      env.head = (env.head + 1) mod MAX_STREAMS
    of "prev":
      env.head = (env.head - 1 + MAX_STREAMS) mod MAX_STREAMS
    of "mv>":
      if env.currentStack.len > 0:
        let i = (env.head + 1) mod MAX_STREAMS
        env.stacks[i] &= env.currentStack.pop
      else:
        echo "Nothing to move"
    of "<mv":
      if env.currentStack.len > 0:
        let i = (env.head - 1 + MAX_STREAMS) mod MAX_STREAMS
        env.stacks[i] &= env.currentStack.pop
      else:
        echo "Nothing to move"
    of "mv<":
      let i = (env.head + 1) mod MAX_STREAMS
      if env.stacks[i].len > 0:
        env.currentStack &= env.stacks[i].pop
      else:
        echo "Nothing to move"
    of ">mv":
      let i = (env.head - 1 + MAX_STREAMS) mod MAX_STREAMS
      if env.stacks[i].len > 0:
        env.currentStack &= env.stacks[i].pop
      else:
        echo "Nothing to move"
    of "cp>":
      if env.currentStack.len > 0:
        let i = (env.head + 1) mod MAX_STREAMS
        env.stacks[i] &= env.currentStack[env.currentStack.high]
      else:
        echo "Nothing to copy"
    of "<cp":
      if env.currentStack.len > 0:
        let i = (env.head - 1 + MAX_STREAMS) mod MAX_STREAMS
        env.stacks[i] &= env.currentStack[env.currentStack.high]
      else:
        echo "Nothing to copy"
    of "cp<":
      let i = (env.head + 1) mod MAX_STREAMS
      if env.stacks[i].len > 0:
        env.currentStack &= env.stacks[i][env.stacks[i].high]
      else:
        echo "Nothing to copy"
    of ">cp":
      let i = (env.head - 1 + MAX_STREAMS) mod MAX_STREAMS
      if env.stacks[i].len > 0:
        env.currentStack &= env.stacks[i][env.stacks[i].high]
      else:
        echo "Nothing to copy"
    of "var", "box":
      if c.len > 1:
        if env.currentStack.len > 0:
          let key = c[1]
          env.variables[key] = env.currentStack.pop
          env.currentStack &= Signal(
            f: proc(ctx: Context): float = env.variables[key].f(ctx),
            label: cmd
          )
        else:
          echo "Stack is empty"
      else:
        echo "Provide a key"
    of "set":
      if c.len > 1:
        if env.currentStack.len > 0:
          env.variables[c[1]] = env.currentStack.pop
        else:
          echo "Stack is empty"
      else:
        echo "Provide a key"
    of "get":
      if c.len > 1:
        let key = c[1]
        if env.variables.hasKey(key):
          env.currentStack &= Signal(
            f: proc(ctx: Context): float = env.variables[key].f(ctx),
            label: "var:" & key
          )
        else:
          echo "Value is not set"
      else:
        echo "Provide a key"
    of "unbox":
      if c.len > 1:
        if env.variables.hasKey(c[1]):
          env.currentStack &= env.variables[c[1]]
        else:
          echo "Value is not set"
      else:
        echo "Provide a key"
    of "osc":
      if c.len > 1:
        let key = c[1]
        if not env.oscVariables.hasKey(key):
          env.oscVariables[key] = box(0.0)
        let s = env.oscVariables[key].toSignal
        s.label = cmd
        env.currentStack &= s
      else:
        echo "Provide a key"
    of "wtable", "wt":
      if c.len > 2:
        if env.currentStack.len > 1:
          let key = c[1]
          let size = c[2].parseInt
          var t = Sampler(table: newSeq[float](size * env.channelCount))
          let x = env.currentStack.pop
          let trigger = env.currentStack.pop
          let delta = sampleNumber - trigger.sampleAndHold(sampleNumber)
          proc f(ctx: Context): float =
            result = x.f(ctx)
            let n = delta.f(ctx).toInt
            if n < size:
              t.table[n + ctx.channel * size] = result
          env.currentStack &= Signal(f: f, label: trigger.label & " " & x.label & " " & cmd)
          env.samplers[key] = t
        else:
          echo "Stack is too short, but trigger and input signals are required"
      else:
        echo "Usage: wtable:<name>:<len>"
    of "rtable", "rt":
      if c.len > 1:
        if env.currentStack.len > 0:
          let key = c[1]
          if env.samplers.hasKey(key):
            let t = env.samplers[key]
            let size = t.table.len div env.channelCount
            let x = env.currentStack.pop
            proc f(ctx: Context): float =
              let z = (x.f(ctx) * ctx.sampleRate.toFloat).splitDecimal
              let i = z[0].toInt
              let k = z[1]
              let offset = ctx.channel * size
              return (1.0 - k) * t.table[(i mod size) + offset] + k * t.table[((i + 1) mod size) + offset]
            env.currentStack &= Signal(f: f, label: x.label & " " & cmd)
          else:
            echo "Table is not found: ", key
        else:
          echo "Stack is empty, but indexing signal required"
      else:
        echo "Usage: rtable:<name>"
    of "ltable", "lt":
      if c.len > 2:
        let key = c[1]
        let path = c[2]
        env.loadTable(key, path)
      else:
        echo "Usage: ltable:<name>:<path>"
    else:
      env.currentStack.execute(cmd)
  for i in 0..<MAX_STREAMS:
    let s = env.stacks[i]
    env.streams[i].signal = if s.len > 0: s[s.high] else: silence

