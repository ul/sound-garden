import audio/signal
import s00, s01, s02
import strutils

# TODO add signal labeling and stack inspection
 
proc execute*(s: var seq[Signal], cmd: string) =
  let e = case cmd
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
  of "-": s.pop - s.pop
  of "*": s.pop * s.pop
  of "/": s.pop / s.pop
  of "add": s.pop + s.pop
  of "sub": s.pop - s.pop
  of "mul": s.pop * s.pop
  of "div": s.pop / s.pop
  of "mod": s.pop mod s.pop
  of "clip": s.pop.clip
  of "wrap": s.pop.wrap
  of "circle": s.pop.circle
  else: cmd.parseFloat.toSignal
  s &= e

