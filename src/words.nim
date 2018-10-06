import analyzers
import audio/signal
import basics
import chebyshev
import delays
import envelopes
import filters
import markov
import maths
import modulation
import oscillators
import spats
import strutils
import triggers
import yin

const stackMarkers = ["⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]

proc word(s: var seq[Signal], f: proc(x: Signal): Signal, label: string) =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  var result = f(x)
  result.label = x.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(x, _: Signal): Signal, label: string, y: Signal) =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  var result = f(x, y)
  result.label = x.label & " " & y.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(x: Signal, _: int): Signal, label: string, y: int) =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  var result = f(x, y)
  result.label = x.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(x, y: Signal): Signal, label: string) =
  if s.len < 2:
    echo "Stack is too short"
    return
  let y = s.pop
  let x = s.pop
  var result = f(x, y)
  result.label = x.label & " " & y.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(x, y, _: Signal): Signal, label: string, z: Signal) =
  if s.len < 2:
    echo "Stack is too short"
    return
  let y = s.pop
  let x = s.pop
  var result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & z.label & " "  & label
  s &= result

proc word(s: var seq[Signal], f: proc(x, y: Signal, _: int): Signal, label: string, z: int) =
  if s.len < 2:
    echo "Stack is too short"
    return
  let y = s.pop
  let x = s.pop
  var result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(x, a, b: Signal): Signal, label: string, y, z: Signal) =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  var result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & z.label & " "  & label
  s &= result

proc word(s: var seq[Signal], f: proc(x: Signal, a: int, b: float): Signal, label: string, y: int, z: float) =
  if s.len < 1:
    echo "Stack is too short"
    return
  let x = s.pop
  var result = f(x, y, z)
  result.label = x.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(x, y, z: Signal): Signal, label: string) =
  if s.len < 3:
    echo "Stack is too short"
    return
  let z = s.pop
  let y = s.pop
  let x = s.pop
  var result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & z.label & " "  & label
  s &= result

proc word(s: var seq[Signal], f: proc(a, b: Signal; c, d: int): Signal, label: string, x, y: int) =
  if s.len < 2:
    echo "Stack is too short"
    return
  let b = s.pop
  let a = s.pop
  var result = f(a, b, x, y)
  result.label = a.label & " " & b.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(a, b, c, d: Signal): Signal, label: string) =
  if s.len < 4:
    echo "Stack is too short"
    return
  let d = s.pop
  let c = s.pop
  let b = s.pop
  let a = s.pop
  var result = f(a, b, c, d)
  result.label = a.label & " " & b.label & " " & c.label & " " & d.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(a, b, c, _: Signal): Signal, label: string, d: Signal) =
  if s.len < 3:
    echo "Stack is too short"
    return
  let c = s.pop
  let b = s.pop
  let a = s.pop
  var result = f(a, b, c, d)
  result.label = a.label & " " & b.label & " " & c.label & " " & d.label & " " & label
  s &= result

proc word(s: var seq[Signal], f: proc(a, b, c, d, e: Signal): Signal, label: string) =
  if s.len < 5:
    echo "Stack is too short"
    return
  let e = s.pop
  let d = s.pop
  let c = s.pop
  let b = s.pop
  let a = s.pop
  var result = f(a, b, c, d, e)
  result.label = a.label & " " & b.label & " " & c.label & " " & d.label & " " & e.label & " " & label
  s &= result

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
      s &= s[s.high]
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
  of "*": s.word(mul, "*")
  of "*.": s.word(`*.`, "*")
  of "+": s.word(add, "+")
  of "-": s.word(sub, "-")
  of ".*": s.word(`.*`, "*")
  of "/": s.word(`div`, "/")
  of "<": s.word(less, "<")
  of "<=": s.word(lessEqual, "<=")
  of "==": s.word(equal, "==")
  of ">": s.word(greater, ">")
  of ">=": s.word(greaterEqual, ">=")
  of "adsr": s.word(adsr, "adsr")
  of "add": s.word(add, "add")
  of "and": s.word(`and`, "and")
  of "or": s.word(`or`, "or")
  of "bqhpf": s.word(biQuadHPF, "bqhpf")
  of "bqlpf": s.word(biQuadLPF, "bqlpf")
  of "cheb2": s.word(cheb2, "cheb2")
  of "cheb3": s.word(cheb3, "cheb3")
  of "cheb4": s.word(cheb4, "cheb4")
  of "cheb5": s.word(cheb5, "cheb5")
  of "cheb6": s.word(cheb6, "cheb6")
  of "cheb7": s.word(cheb7, "cheb7")
  of "cheb8": s.word(cheb8, "cheb8")
  of "cheb9": s.word(cheb9, "cheb9")
  of "circle", "angular": s.word(circle, "circle")
  of "clausen": s.word(clausen, "clausen", 100)
  of "clip": s.word(clip, "clip", -1.0, 1.0)
  of "cos": s.word(cos, "cos")
  of "cosh": s.word(cosh, "cosh")
  of "cosine": s.word(cosine, "cosine")
  of "delay": s.word(delay, "delay", 60*48000)
  of "sdelay": s.word(smoothDelay, "sdelay", 256, 60*48000)
  of "div": s.word(`div`, "div")
  of "exp": s.word(exp, "exp")
  of "fb": s.word(feedback, "fb")
  of "fm": s.word(fm, "fm", 0)
  of "sfb": s.word(smoothFeedback, "sfb")
  of "gaussian": s.word(gaussian, "gaussian")
  of "h": s.word(biQuadHPF, "bqhpf", 0.7071)
  of "hcosine": s.word(hcosine, "hcosine")
  of "hpf": s.word(hpf, "hpf")
  of "hsine": s.word(hsine, "hsine")
  of "htangent": s.word(htangent, "htangent")
  of "impulse": s.word(impulse, "impulse")
  of "input", "in", "mic": s &= input
  of "l": s.word(biQuadLPF, "bqlpf", 0.7071)
  of "line": s.word(line, "line")
  of "lpf": s.word(lpf, "lpf")
  of "markov": s.word(markovSample, "markov")
  of "max": s.word(max, "max")
  of "min": s.word(min, "min")
  of "metro", "m": s.word(metro, "metro")
  of "metroh", "mh": s.word(metroHold, "metroh")
  of "dmetro", "dm": s.word(dmetro, "dmetro")
  of "dmetroh", "dmh": s.word(dmetroHold, "dmetroh")
  of "mod": s.word(`mod`, "mod")
  of "mul": s.word(mul, "mul")
  of "p": s.word(pulse, "pulse", 0)
  of "pan": s.word(pan, "pan")
  of "pitch": s.word(yin.pitch, "pitch", 1024, 0.2)
  of "pm": s.word(pm, "pm", 0)
  of "prime": s.word(prime, "prime")
  of "project": s.word(project, "project")
  of "pulse": s.word(pulse, "pulse")
  of "quantize": s.word(quantize, "quantize")
  of "range", "[]", "r": s.word(basics.range, "range")
  of "rectangle": s.word(rectangle, "rectangle")
  of "round": s.word(round, "round")
  of "s": s.word(sine, "sine", 0)
  of "saw": s.word(saw, "saw")
  of "sh": s.word(sampleAndHold, "sh")
  of "silence": s &= silence
  of "sin": s.word(sin, "sin")
  of "sine": s.word(sine, "sine")
  of "sinh": s.word(sinh, "sinh")
  of "sub": s.word(sub, "sub")
  of "t": s.word(tri, "tri", 0)
  of "tan": s.word(tan, "tan")
  of "tangent": s.word(tangent, "tangent")
  of "tanh": s.word(tanh, "tanh")
  of "tri": s.word(tri, "tri")
  of "triangle": s.word(triangle, "triangle")
  of "unit": s.word(unit, "unit")
  of "w": s.word(saw, "saw", 0)
  of "whiteNoise", "noise", "n": s &= whiteNoise
  of "wrap": s.word(wrap, "wrap", -1.0, 1.0)
  of "db2amp", "db2a": s.word(db2amp.toSignal, "db2amp")
  of "amp2db", "a2db": s.word(amp2db.toSignal, "amp2db")
  of "freq2midi", "f2m": s.word(freq2midi.toSignal, "freq2midi")
  of "midi2freq", "m2f": s.word(midi2freq.toSignal, "midi2freq")
  else:
    try:
      s &= cmd.parseFloat.toSignal
    except ValueError:
      echo "Unknown command: " & cmd

