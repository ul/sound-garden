import audio/signal
import s00, s01, s02, s03
import strutils

const stackMarkers = ["⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]

proc execute*(s: var seq[Signal], cmd: string) =
  case cmd
  of "dump":
    for i in countdown(s.high, s.low):
      let j = s.high - i
      let m = if j < stackMarkers.len: stackMarkers[j] else: $i
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
    of "mono": s.pop.channel(0)
    of "silence": silence
    of "whiteNoise": whiteNoise
    of "triangle": s.pop.triangle
    of "rectangle":
      let width = s.pop
      s.pop.rectangle(width)
    of "saw": s.pop.saw
    of "tri": s.pop.tri
    of "pulse":
      let width = s.pop
      let freq = s.pop
      freq.pulse(width)
    of "sin": s.pop.sin
    of "sine": s.pop.sine
    of "cos": s.pop.cos
    of "cosine": s.pop.cosine
    of "tan": s.pop.tan
    of "tangent": s.pop.tangent
    of "sinh": s.pop.sinh
    of "hsine": s.pop.hsine
    of "cosh": s.pop.cosh
    of "hcosine": s.pop.hcosine
    of "tanh": s.pop.tanh
    of "htangent": s.pop.htangent
    of "+": s.pop + s.pop
    of "-":
      let b = s.pop
      let a = s.pop
      a - b
    of "*": s.pop * s.pop
    of "/":
      let b = s.pop
      let a = s.pop
      a / b
    of "add": s.pop + s.pop
    of "sub":
      let b = s.pop
      let a = s.pop
      a - b
    of "mul": s.pop * s.pop
    of "div": 
      let b = s.pop
      let a = s.pop
      a / b
    of "mod":
      let b = s.pop
      let a = s.pop
      a mod b
    of "clip": s.pop.clip
    of "wrap": s.pop.wrap
    of "circle": s.pop.circle
    of "clausen": s.pop.clausen
    of "pan":
      let c = s.pop
      let right = s.pop
      let left = s.pop
      pan(left, right, c)
    of "sh":
      let x = s.pop
      let trig = s.pop
      sampleAndHold(trig, x)
    of "pitch":
      s.pop.pitch
    of "prime":
      s.pop.prime
    of "uuu":
      s.pop.uuu
    of "nnn":
      s.pop.nnn
    of "mmm":
      s.pop.mmm
    else:
      var x: Signal
      try:
        x = cmd.parseFloat.toSignal
      except ValueError:
        echo "Unknown command: " & cmd
        return
      x
    s &= e

