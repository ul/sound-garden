import locks

type
  Box*[T] = object
    value: ptr T
    lock: Lock

proc init[T](b: var Box[T]) =
  initLock b.lock
  b.value = cast[ptr T](T.sizeof.alloc)

proc `=destroy`[T](b: var Box[T]) =
  b.value.dealloc

proc get*[T](b: Box[T]): T = b.value[]

proc set*[T](b: var Box[T], x: T) =
  # TODO consider withLock
  b.value[] = x

proc update*[T](b: var Box[T], f: proc(x: T): T) =
  withLock b.lock:
    b.value[] = f(b.value[])

proc box*[T](x: T): Box[T] =
  result = Box[T]()
  result.init()
  result.set(x)

