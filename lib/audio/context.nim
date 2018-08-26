type
  Context* = ref object
    channel*: int
    sampleNumber*: int
    sampleRate*: int

proc sampleDuration*(ctx: Context): float = 1.0 / ctx.sampleRate.toFloat

proc time*(ctx: Context): float = ctx.sampleNumber.toFloat / ctx.sampleRate.toFloat

