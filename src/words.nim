import analyzers
import audio/signal
import basics
import delays
import envelopes
import filters
import maths
import oscillators
import spats
import strutils
import triggers
import yin

const stackMarkers = ["⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]

proc word(s: var seq[Signal], f: proc(x: Signal): Signal, label: string): Signal =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  result = f(x)
  result.label = x.label & " " & label

proc word(s: var seq[Signal], f: proc(x, _: Signal): Signal, label: string, y: Signal): Signal =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  result = f(x, y)
  result.label = x.label & " " & y.label & " " & label

proc word(s: var seq[Signal], f: proc(x: Signal, _: int): Signal, label: string, y: int): Signal =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  result = f(x, y)
  result.label = x.label & " " & label

proc word(s: var seq[Signal], f: proc(x, y: Signal): Signal, label: string): Signal =
  if s.len < 2:
    echo "Stack is too short"
    return
  let y = s.pop
  let x = s.pop
  result = f(x, y)
  result.label = x.label & " " & y.label & " " & label

proc word(s: var seq[Signal], f: proc(x, y, _: Signal): Signal, label: string, z: Signal): Signal =
  if s.len < 2:
    echo "Stack is too short"
    return
  let y = s.pop
  let x = s.pop
  result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & z.label & " "  & label

proc word(s: var seq[Signal], f: proc(x, y: Signal, _: int): Signal, label: string, z: int): Signal =
  if s.len < 2:
    echo "Stack is too short"
    return
  let y = s.pop
  let x = s.pop
  result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & label

proc word(s: var seq[Signal], f: proc(x, a, b: Signal): Signal, label: string, y, z: Signal): Signal =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & z.label & " "  & label

proc word(s: var seq[Signal], f: proc(x: Signal, a: int, b: float): Signal, label: string, y: int, z: float): Signal =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  result = f(x, y, z)
  result.label = x.label & " " & label

proc word(s: var seq[Signal], f: proc(x, y, z: Signal): Signal, label: string): Signal =
  if s.len < 3:
    echo "Stack is too short"
    return
  let z = s.pop
  let y = s.pop
  let x = s.pop
  result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & z.label & " "  & label

proc word(s: var seq[Signal], f: proc(a, b: Signal; c, d: int): Signal, label: string, x, y: int): Signal =
  if s.len < 2:
    echo "Stack is too short"
    return
  let b = s.pop
  let a = s.pop
  result = f(a, b, x, y)
  result.label = a.label & " " & b.label & " " & label

proc word(s: var seq[Signal], f: proc(a, b, c, d, e: Signal): Signal, label: string): Signal =
  if s.len < 5:
    echo "Stack is too short"
    return
  let e = s.pop
  let d = s.pop
  let c = s.pop
  let b = s.pop
  let a = s.pop
  result = f(a, b, c, d, e)
  result.label = a.label & " " & b.label & " " & c.label & " " & d.label & " " & e.label & label

proc execute*(s: var seq[Signal], cmd: string) =
  case cmd
  of "empty":
    s.setLen(0)
  of "dump":
    if s.len == 0:
      echo "<empty>"
    else:
      let low = max(s.low, s.high - 9)
      for i in countdown(s.high, low):
        let j = s.high - i
        let m = if j < stackMarkers.len: stackMarkers[j] else: $j & ")"
        echo m, " ", s[i].label
  of "dumpall":
    if s.len == 0:
      echo "<empty>"
    else:
      for i in countdown(s.high, s.low):
        let j = s.high - i
        let m = if j < stackMarkers.len: stackMarkers[j] else: $j & ")"
        echo m, " ", s[i].label
  of "pop":
    if s.len > 0:
      discard s.pop
    else:
      echo "Nothing to pop"
  of "swap":
    if s.len > 1:
      let i = s.high
      let a = s[i-1]
      let b = s[i]
      s[i] = a
      s[i-1] = b
    else:
      echo "Stack is too short"
  of "rot":
    if s.len > 2:
      let i = s.high
      let a = s[i-2]
      let b = s[i-1]
      let c = s[i]
      s[i] = a
      s[i-1] = c
      s[i-2] = b
    else:
      echo "Stack is too short"
  of "dup":
    if s.len > 0:
      let x = s[s.high]
      let y = Signal(f: x.f, label: "(" & x.label & " dup)")
      s &= y
    else:
      echo "Stack is too short"
  of "ch0":
    if s.len > 0:
      let x = s.pop
      let y = x.channel(0)
      y.label = x.label & " ch0"
      s &= y
    else:
      echo "Stack is too short"
  of "ch1":
    if s.len > 0:
      let x = s.pop
      let y = x.channel(1)
      y.label = x.label & " ch1"
      s &= y
    else:
      echo "Stack is too short"
  of "*": s &= s.word(mul, "*")
  of "*.": s &= s.word(`*.`, "*")
  of "+": s &= s.word(add, "+")
  of "-": s &= s.word(sub, "-")
  of ".*": s &= s.word(`.*`, "*")
  of "/": s &= s.word(`div`, "/")
  of "<": s &= s.word(less, "<")
  of "<=": s &= s.word(lessEqual, "<=")
  of "==": s &= s.word(equal, "==")
  of ">": s &= s.word(greater, ">")
  of ">=": s &= s.word(greaterEqual, ">=")
  of "add": s &= s.word(add, "add")
  of "and": s &= s.word(`and`, "and")
  of "or": s &= s.word(`or`, "or")
  of "bqhpf": s &= s.word(biQuadHPF, "bqhpf")
  of "bqlpf": s &= s.word(biQuadLPF, "bqlpf")
  of "circle", "angular": s &= s.word(circle, "circle")
  of "clausen": s &= s.word(clausen, "clausen", 100)
  of "clip": s &= s.word(clip, "clip", -1.0, 1.0)
  of "cos": s &= s.word(cos, "cos")
  of "cosh": s &= s.word(cosh, "cosh")
  of "cosine": s &= s.word(cosine, "cosine")
  of "delay": s &= s.word(delay, "delay", 60*48000)
  of "sdelay": s &= s.word(smoothDelay, "sdelay", 256, 60*48000)
  of "ssdelay": s &= s.word(smoothestDelay, "ssdelay", 256, 60*48000)
  of "div": s &= s.word(`div`, "div")
  of "exp": s &= s.word(exp, "exp")
  of "fb": s &= s.word(feedback, "fb")
  of "sfb": s &= s.word(smoothFeedback, "sfb")
  of "ssfb": s &= s.word(smoothestFeedback, "ssfb")
  of "h": s &= s.word(biQuadHPF, "bqhpf", 0.7071)
  of "hcosine": s &= s.word(hcosine, "hcosine")
  of "hpf": s &= s.word(hpf, "hpf")
  of "hsine": s &= s.word(hsine, "hsine")
  of "htangent": s &= s.word(htangent, "htangent")
  of "impulse": s &= s.word(impulse, "impulse")
  of "input", "in", "mic": s &= input
  of "l": s &= s.word(biQuadLPF, "bqlpf", 0.7071)
  of "lpf": s &= s.word(lpf, "lpf")
  of "max": s &= s.word(max, "max")
  of "min": s &= s.word(min, "min")
  of "metro", "m": s &= s.word(metro, "metro")
  of "dmetro", "dm": s &= s.word(dmetro, "dmetro")
  of "mod": s &= s.word(`mod`, "mod")
  of "mul": s &= s.word(mul, "mul")
  of "p": s &= s.word(pulse, "pulse", 0)
  of "pan": s &= s.word(pan, "pan")
  of "pitch": s &= s.word(yin.pitch, "pitch", 1024, 0.2)
  of "prime": s &= s.word(prime, "prime")
  of "project": s &= s.word(project, "project")
  of "pulse": s &= s.word(pulse, "pulse")
  of "quantize": s &= s.word(quantize, "quantize")
  of "range", "[]", "r": s &= s.word(basics.range, "range")
  of "rectangle": s &= s.word(rectangle, "rectangle")
  of "round": s &= s.word(round, "round")
  of "s": s &= s.word(sine, "sine", 0)
  of "saw": s &= s.word(saw, "saw")
  of "sh": s &= s.word(sampleAndHold, "sh")
  of "silence": s &= silence
  of "sin": s &= s.word(sin, "sin")
  of "sine": s &= s.word(sine, "sine")
  of "sinh": s &= s.word(sinh, "sinh")
  of "sub": s &= s.word(sub, "sub")
  of "t": s &= s.word(tri, "tri", 0)
  of "tan": s &= s.word(tan, "tan")
  of "tangent": s &= s.word(tangent, "tangent")
  of "tanh": s &= s.word(tanh, "tanh")
  of "tri": s &= s.word(tri, "tri")
  of "triangle": s &= s.word(triangle, "triangle")
  of "unit": s &= s.word(unit, "unit")
  of "w": s &= s.word(saw, "saw", 0)
  of "whiteNoise", "noise", "n": s &= whiteNoise
  of "wrap": s &= s.word(wrap, "wrap", -1.0, 1.0)
  of "db2amp", "db2a": s &= s.word(db2amp.toSignal, "db2amp")
  of "amp2db", "a2db": s &= s.word(amp2db.toSignal, "amp2db")
  of "freq2midi", "f2m": s &= s.word(freq2midi.toSignal, "freq2midi")
  of "midi2freq", "m2f": s &= s.word(midi2freq.toSignal, "midi2freq")
  else:
    try:
      s &= cmd.parseFloat.toSignal
    except ValueError:
      echo "Unknown command: " & cmd

