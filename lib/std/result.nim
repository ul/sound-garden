type
  ResultKind* = enum Ok, Err
  Result*[T] = object
    case kind*: ResultKind
    of Ok: value*: T
    of Err: msg*: string
