import environment
import interpreter
import os
import strutils
when not defined(windows):
  import osc
  import tui

proc repl*(env: Environment) =
  while true:
    stdout.write "[", env.head, "]> "
    try:
      let line = stdin.readLine.strip
      if line == "quit":
        break
      env.interpret(line)
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
