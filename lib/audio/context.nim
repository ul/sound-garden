import math

type
  Context* = ref object
    channel*: int
    sampleNumber*: int
    sampleRate*: int

const TWOPI* = 2.0 * PI

proc sampleDuration*(ctx: Context): float = 1.0 / ctx.sampleRate.toFloat

proc sampleAngularPeriod*(ctx: Context): float = TWOPI / ctx.sampleRate.toFloat

proc time*(ctx: Context): float = ctx.sampleNumber.toFloat / ctx.sampleRate.toFloat

