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
  let args = commandLineParams()
  if args.contains("osc"):
    discard osc.start(env)
  if args.contains("tui"):
    env.run
  else:
    env.repl
