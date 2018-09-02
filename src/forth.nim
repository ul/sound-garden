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

const stackMarkers = ["⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]

proc word(s: var seq[Signal], f: proc(x: Signal): Signal, label: string): Signal =
  let x = s.pop
  result = f(x)
  result.label = x.label & " " & label

proc word(s: var seq[Signal], f: proc(x, _: Signal): Signal, label: string, y: Signal): Signal =
  let x = s.pop
  result = f(x, y)
  result.label = x.label & " " & y.label & " " & label

proc word(s: var seq[Signal], f: proc(x: Signal, _: int): Signal, label: string, y: int): Signal =
  let x = s.pop
  result = f(x, y)
  result.label = x.label & " " & label

proc word(s: var seq[Signal], f: proc(x, y: Signal): Signal, label: string): Signal =
  let y = s.pop
  let x = s.pop
  result = f(x, y) 
  result.label = x.label & " " & y.label & " " & label

proc word(s: var seq[Signal], f: proc(x, y, _: Signal): Signal, label: string, z: Signal): Signal =
  let y = s.pop
  let x = s.pop
  result = f(x, y, z) 
  result.label = x.label & " " & y.label & " " & z.label & " "  & label

proc word(s: var seq[Signal], f: proc(x, y: Signal, _: int): Signal, label: string, z: int): Signal =
  let y = s.pop
  let x = s.pop
  result = f(x, y, z) 
  result.label = x.label & " " & y.label & " " & label

proc word(s: var seq[Signal], f: proc(x, a, b: Signal): Signal, label: string, y, z: Signal): Signal =
  let x = s.pop
  result = f(x, y, z)
  result.label = x.label & " " & y.label & " " & z.label & " "  & label

proc word(s: var seq[Signal], f: proc(x, y, z: Signal): Signal, label: string): Signal =
  let z = s.pop
  let y = s.pop
  let x = s.pop
  result = f(x, y, z) 
  result.label = x.label & " " & y.label & " " & z.label & " "  & label

proc word(s: var seq[Signal], f: proc(a, b, c, d: Signal): Signal, label: string): Signal =
  let d = s.pop
  let c = s.pop
  let b = s.pop
  let a = s.pop
  result = f(a, b, c, d) 
  result.label = a.label & " " & b.label & " " & c.label & " " & d.label & label

proc word(s: var seq[Signal], f: proc(a, b, c, d, e: Signal): Signal, label: string): Signal =
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
  of "swap":
    if s.len > 1:
      let i = s.high
      let a = s[i-1]
      let b = s[i]
      s[i] = a
      s[i-1] = b
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
    let e = case cmd
    of "dup":
      let x = s[s.high]
      let y = Signal(f: x.f, label: "(" & x.label & " dup)")
      y
    of "ch0":
      let x = s.pop
      let y = x.channel(0)
      y.label = x.label & " ch0"
      y
    of "ch1":
      let x = s.pop
      let y = x.channel(1)
      y.label = x.label & " ch1"
      y
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
    of "add": s.word(add, "add")
    of "bqhpf": s.word(biQuadHPF, "bqhpf")
    of "bqlpf": s.word(biQuadLPF, "bqlpf")
    of "circle": s.word(circle, "circle")
    of "clausen": s.word(clausen, "clausen", 100)
    of "clip": s.word(clip, "clip", -1.0, 1.0)
    of "cos": s.word(cos, "cos")
    of "cosh": s.word(cosh, "cosh")
    of "cosine": s.word(cosine, "cosine")
    of "delay": s.word(delay, "delay", 5*48000)
    of "div": s.word(`div`, "div")
    of "exp": s.word(exp, "exp")
    of "fb": s.word(feedback, "fb")
    of "h": s.word(biQuadHPF, "bqhpf", 0.7071)
    of "hcosine": s.word(hcosine, "hcosine")
    of "hpf": s.word(hpf, "hpf")
    of "hsine": s.word(hsine, "hsine")
    of "htangent": s.word(htangent, "htangent")
    of "impulse": s.word(impulse, "impulse")
    of "l": s.word(biQuadLPF, "bqlpf", 0.7071)
    of "lpf": s.word(lpf, "lpf")
    of "max": s.word(max, "max")
    of "min": s.word(min, "min")
    of "mod": s.word(`mod`, "mod")
    of "mul": s.word(mul, "mul")
    of "n": whiteNoise
    of "noise": whiteNoise
    of "p": s.word(pulse, "pulse", 0)
    of "pan": s.word(pan, "pan")
    of "pitch": s.word(adaptivePitch, "pitch", 10)
    of "prime": s.word(prime, "prime")
    of "project": s.word(project, "project")
    of "pulse": s.word(pulse, "pulse")
    of "range": s.word(basics.range, "range")
    of "rectangle": s.word(rectangle, "rectangle")
    of "s": s.word(sine, "sine", 0)
    of "saw": s.word(saw, "saw")
    of "sh": s.word(sampleAndHold, "sh")
    of "silence": silence
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
    of "whiteNoise": whiteNoise
    of "wrap": s.word(wrap, "wrap", -1.0, 1.0)
    else:
      var x: Signal
      try:
        x = cmd.parseFloat.toSignal
      except ValueError:
        echo "Unknown command: " & cmd
        return
      x
    s &= e

