import environment
import interpreter
import osc

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
  env.repl
