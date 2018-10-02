import math

type
  Context* = ref object
    channel*: int
    sampleNumber*: int
    sampleRate*: int
    sampleRateFloat*: float
    sampleDuration*: float
    input*: float

const TWOPI* = 2.0 * PI

proc sampleAngularPeriod*(ctx: Context): float = TWOPI * ctx.sampleDuration

proc time*(ctx: Context): float = ctx.sampleNumber.toFloat * ctx.sampleDuration

