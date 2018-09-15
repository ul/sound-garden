import environment
import interpreter
import os
import osc
import tui

proc repl*(env: Environment) =
  while true:
    stdout.write "[", env.head, "]> "
    try:
      env.interpret(stdin.readLine)
    except EOFError:
      break

when isMainModule:
  var env = environment.init()
  discard osc.start(env)
  if paramCount() > 0 and paramStr(1) == "tui":
    env.run
  else:
    env.repl
