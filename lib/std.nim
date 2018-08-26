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
