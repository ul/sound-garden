import audio/signal
import s00, s01, s02, s03, s04
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

proc execute*(s: var seq[Signal], cmd: string) =
  case cmd
  of "dump":
    if s.len == 0:
      echo "<empty>"
    else:
      for i in countdown(s.high, s.low):
        let j = s.high - i
        let m = if j < stackMarkers.len: stackMarkers[j] else: $j
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
    of "dup": s[s.high]
    of "mono0":
      let x = s.pop
      let y = x.channel(0)
      y.label = x.label & " mono0"
      y
    of "mono1":
      let x = s.pop
      let y = x.channel(1)
      y.label = x.label & " mono1"
      y
    of "silence": silence
    of "whiteNoise": whiteNoise
    of "noise": whiteNoise
    of "n": whiteNoise
    of "triangle": s.word(triangle, "triangle")
    of "rectangle": s.word(rectangle, "rectangle")
    of "saw": s.word(saw, "saw")
    of "w": s.word(saw, "saw", 0)
    of "tri": s.word(tri, "tri")
    of "t": s.word(tri, "tri", 0)
    of "pulse": s.word(pulse, "pulse")
    of "p": s.word(pulse, "pulse", 0)
    of "sin": s.word(sin, "sin")
    of "sine": s.word(sine, "sine")
    of "s": s.word(sine, "sine", 0)
    of "cos": s.word(cos, "cos")
    of "cosine": s.word(cosine, "cosine")
    of "tan": s.word(tan, "tan")
    of "tangent": s.word(tangent, "tangent")
    of "sinh": s.word(sinh, "sinh")
    of "hsine": s.word(hsine, "hsine")
    of "cosh": s.word(cosh, "cosh")
    of "hcosine": s.word(hcosine, "hcosine")
    of "tanh": s.word(tanh, "tanh")
    of "htangent": s.word(htangent, "htangent")
    of ">": s.word(greater, ">")
    of ">=": s.word(greaterEqual, ">=")
    of "<": s.word(less, "<")
    of "<=": s.word(lessEqual, "<=")
    of "==": s.word(equal, "==")
    of "+": s.word(add, "+")
    of "-": s.word(sub, "-")
    of "*": s.word(mul, "*")
    of ".*": s.word(`.*`, "*")
    of "*.": s.word(`*.`, "*")
    of "/": s.word(`div`, "/")
    of "add": s.word(add, "add")
    of "sub": s.word(sub, "sub")
    of "mul": s.word(mul, "mul")
    of "div": s.word(`div`, "div")
    of "mod": s.word(`mod`, "mod")
    of "clip": s.word(clip, "clip", -1.0, 1.0)
    of "wrap": s.word(wrap, "wrap", -1.0, 1.0)
    of "circle": s.word(circle, "circle")
    of "clausen": s.word(clausen, "clausen", 100)
    of "pan": s.word(pan, "pan")
    of "sh": s.word(sampleAndHold, "sh")
    of "pitch": s.word(adaptivePitch, "pitch", 10)
    of "prime": s.word(prime, "prime")
    of "lpf": s.word(lpf, "lpf")
    of "hpf": s.word(hpf, "hpf")
    of "bqlpf": s.word(biQuadLPF, "bqlpf")
    of "l": s.word(biQuadLPF, "bqlpf", 0.7071)
    of "bqhpf": s.word(biQuadHPF, "bqhpf")
    of "h": s.word(biQuadHPF, "bqhpf", 0.7071)
    of "fb": s.word(feedback, "fb")
    else:
      var x: Signal
      try:
        x = cmd.parseFloat.toSignal
      except ValueError:
        echo "Unknown command: " & cmd
        return
      x
    s &= e

