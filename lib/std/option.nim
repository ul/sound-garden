type
  OptionKind* = enum None, Some
  Option*[T] = object
    case kind*: OptionKind
    of Some: value*: T
    of None: discard

