import environment
import interpreter
import os
when not defined(windows):
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
  let args = commandLineParams()
  var env = environment.init(args.contains("--with-input"))
  when not defined(windows):
    if args.contains("--with-osc"):
      discard osc.start(env)
    if args.contains("--tui"):
      env.run
    else:
      env.repl
  else:
    env.repl
