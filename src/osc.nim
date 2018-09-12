import environment
import interpreter
import lo/[lo, lo_serverthread, lo_types, lo_osc_types]
import tables
import std
import strutils

type
  OSCServerThread* = ref object
    env: Environment
    thread: lo_server_thread

proc error(num: cint; msg: cstring; where: cstring) {.cdecl.} =
  echo "liblo server error ", num, " in path ", where, ": ", msg

proc interpret_handler(path: cstring; types: cstring; argv: ptr ptr lo_arg; argc: cint; msg: lo_message; user_data: pointer): cint {.cdecl.} =
  let arg0 = cast[ptr lo_arg](argv[])
  let line: cstring = arg0.s.addr
  let env = cast[ptr Environment](user_data)[]
  env.interpret($line)

proc accxyz_handler(path: cstring; types: cstring; argv: ptr ptr lo_arg; argc: cint; msg: lo_message; user_data: pointer): cint {.cdecl.} =
  let argvi = cast[int](argv)
  let psz = pointer.sizeof
  let arg0 = cast[ptr lo_arg](argv[])
  let arg1 = cast[ptr lo_arg](cast[ptr ptr lo_arg](argvi + psz)[])
  let arg2 = cast[ptr lo_arg](cast[ptr ptr lo_arg](argvi + 2 * psz)[])
  let env = cast[ptr Environment](user_data)[]
  env.oscVariables["x"].set(arg0.f)
  env.oscVariables["y"].set(arg1.f)
  env.oscVariables["z"].set(arg2.f)

proc var_set_handler(path: cstring; types: cstring; argv: ptr ptr lo_arg; argc: cint; msg: lo_message; user_data: pointer): cint {.cdecl.} =
  var path = $path
  if not path.startsWith("/set/"):
    return 1
  path.removePrefix("/set/")
  let arg0 = cast[ptr lo_arg](argv[])
  let env = cast[ptr Environment](user_data)[]
  if not env.oscVariables.hasKey(path):
    env.oscVariables[path] = box(0.0)
  env.oscVariables[path].set(arg0.f)

proc start*(env: var Environment): OSCServerThread =
  GC_ref env

  let oscServerThread = lo_server_thread_new("7770", error);

  discard lo_server_thread_add_method(oscServerThread, "/interpret", "s", interpret_handler, env.addr);
  discard lo_server_thread_add_method(oscServerThread, "/accxyz", "fff", accxyz_handler, env.addr);
  discard lo_server_thread_add_method(oscServerThread, nil, "f", var_set_handler, env.addr);

  discard lo_server_thread_start(oscServerThread)

  OSCServerThread(env: env, thread: oscServerThread)

proc `=destroy`(t: var OSCServerThread) =
  GC_unref t.env
  t.thread.lo_server_thread_free
