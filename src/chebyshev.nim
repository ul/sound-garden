import audio/[context, signal]

# T2(x) = 2x2 − 1
proc cheb2*(x: Signal): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    return 2.0 * x * x - 1.0
  Signal(f: f)

# T3(x) = 4x3 − 3x
proc cheb3*(x: Signal): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    return 4.0 * x * x * x - 3.0 * x
  Signal(f: f)

# T4(x) = 8x4 − 8x2 + 1
proc cheb4*(x: Signal): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let x2 = x * x
    return 8.0 * x2 * (x2 - 1.0) + 1.0
  Signal(f: f)

# 16x5 − 20x3 + 5x
proc cheb5*(x: Signal): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let x2 = x * x
    let x3 = x2 * x
    return 16.0 * x2 * x3 - 20.0 * x3 + 5.0 * x
  Signal(f: f)

# T6(x) = 32x6 −48x4 +18x2 −1
proc cheb6*(x: Signal): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let x2 = x * x
    let x4 = x2 * x2
    return 32.0 * x2 * x4 - 48.0 * x4 + 18.0 * x2 - 1.0
  Signal(f: f)

# T7(x) = 64x7 − 112x5 + 56x3 − 7x
proc cheb7*(x: Signal): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let x2 = x * x
    let x3 = x2 * x
    let x5 = x3 * x2
    let x7 = x5 * x2
    return 64.0 * x7 - 112.0 * x5 + 56.0 * x3 - 7.0 * x
  Signal(f: f)

# T8(x) = 128x8 − 256x6 + 160x4 − 32x2 + 1
proc cheb8*(x: Signal): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let x2 = x * x
    let x4 = x2 * x2
    let x6 = x4 * x2
    let x8 = x4 * x4
    return 128.0 * x8 - 256.0 * x6 + 160.0 * x4 - 32.0 * x2 + 1.0
  Signal(f: f)

# T9(x) = 256x9 − 576x7 + 432x5 − 120x3 + 9x
proc cheb9*(x: Signal): Signal =
  proc f(ctx: Context): float =
    let x = x.f(ctx)
    let x2 = x * x
    let x3 = x2 * x
    let x5 = x3 * x2
    let x7 = x5 * x2
    let x9 = x7 * x2
    return 256.0 * x9 - 576.0 * x7 + 432.0 * x5 - 120.0 * x3 + 9.0 * x
  Signal(f: f)
