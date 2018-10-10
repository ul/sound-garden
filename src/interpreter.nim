import audio/[audio, context, signal]
import basics
import disk
import environment
import granular
import math
import maths
import samplers
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
    else:
      env.execute(env.currentStack, cmd)
  for i in 0..<MAX_STREAMS:
    let s = env.stacks[i]
    env.streams[i].signal = if s.len > 0: s[s.high] else: silence

