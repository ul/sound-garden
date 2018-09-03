{.deadCodeElim: on.}
include
  std/result,
  std/option,
  std/box

proc `&&`*(self: string, other: string): string =
  if self == nil:
    return other
  elif other == nil:
    return self
  else:
    return self & other

# NOTE not the fastest way, but we don't use it in a tight loop
# the only reson we can't use math.log2 because we need impl for int, not float
proc log2*(x: int): int =
  var v = x shr 1
  while v != 0:
    result += 1
    v = v shr 1

