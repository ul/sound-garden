import std
import soundio
import context
import signal

GC_setMaxPause 300 # microseconds
 
type
  SoundSystem* = object
    sio*: ptr SoundIo
    device*: ptr SoundIoDevice
  OutStream* = object
    stream*: ptr SoundIoOutStream
    userdata: ptr UserData
  UserData = object
    context: Context
    signal: Signal

let sizeOfChannelArea = sizeof SoundIoChannelArea

proc writeCallback(outStream: ptr SoundIoOutStream, frameCountMin: cint, frameCountMax: cint) {.cdecl.} =
  GC_disable()

  let userdata = cast[ptr UserData](outStream.userdata)
  let ctx = userdata.context
  let signal = userdata.signal.f
  let channelCount = outstream.layout.channelCount
  var areas: ptr SoundIoChannelArea
  var framesLeft = frameCountMax
  var err: cint

  while true:
    var frameCount = framesLeft

    err = outStream.beginWrite(areas.addr, frameCount.addr)
    if err > 0:
      quit "Unrecoverable stream error: " & $err.strerror
    if frameCount <= 0:
      break

    let ptrAreas = cast[int](areas)

    for frame in 0..<frameCount:
      for channel in 0..<channelCount:
        ctx.channel = channel
        let ptrArea = cast[ptr SoundIoChannelArea](ptrAreas + channel*sizeOfChannelArea)
        var ptrSample = cast[ptr float32](cast[int](ptrArea.pointer) + frame*ptrArea.step)
        ptrSample[] = signal(ctx).float32
      ctx.sampleNumber += 1

    err = outstream.endWrite
    if err > 0 and err != cint(SoundIoError.Underflow):
      quit "Unrecoverable stream error: " & $err.strerror

    framesLeft -= frameCount
    if framesLeft <= 0:
      break

  GC_enable()

proc sserr(msg: string): Result[SoundSystem] =
  return Result[SoundSystem](kind: Err, msg: msg)

proc oserr(msg: string): Result[OutStream] =
  return Result[OutStream](kind: Err, msg: msg)

proc newSoundSystem*(): Result[SoundSystem] =
  let sio = soundioCreate()
  if sio.isNil:
    return sserr "out of mem"

  var err = sio.connect
  if err > 0:
    return sserr "Unable to connect to backend: " & $err.strerror

  echo "Backend: \t", sio.currentBackend.name
  sio.flushEvents

  let devID = sio.defaultOutputDeviceIndex
  if devID < 0:
    return sserr "Output device is not found"
  let device = sio.getOutputDevice(devID)
  if device.isNil:
    return sserr "out of mem"
  if device.probeError > 0:
    return sserr "Cannot probe device"

  echo "Output device:\t", device.name

  return Result[SoundSystem](
    kind: Ok,
    value: SoundSystem(sio: sio, device: device))

proc newOutStream*(ss: SoundSystem): Result[OutStream] =
  let stream = ss.device.outStreamCreate
  stream.write_callback = writeCallback

  var err = stream.open
  if err > 0:
    return oserr "Unable to open device: " & $err.strerror

  if stream.layoutError > 0:
    return oserr "Unable to set channel layout: " & $stream.layoutError.strerror

  err = stream.start
  if err > 0:
    return oserr "Unable to start stream: " & $err.strerror

  stream.userdata = UserData.sizeof.alloc

  var ctx = Context(channel: 0, sampleNumber: 0, sampleRate: stream.sampleRate)
  var silence = 0.toSignal

  GC_ref ctx
  GC_ref silence

  var userdata = cast[ptr UserData](stream.userdata)
  userdata.context = ctx
  userdata.signal = silence

  return Result[OutStream](kind: Ok, value: OutStream(stream: stream, userdata: userdata))

proc `=destroy`(s: var SoundSystem) =
  s.device.unref
  s.sio.destroy

proc `=destroy`(s: var OutStream) =
  s.stream.destroy
  GC_unref s.userdata.signal
  GC_unref s.userdata.context
  s.userdata.dealloc

proc `signal=`*(stream: OutStream, s: Signal) =
  GC_unref stream.userdata.signal
  stream.userdata.signal = s
  GC_ref stream.userdata.signal
