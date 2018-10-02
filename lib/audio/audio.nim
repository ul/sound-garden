import math
import std
import soundio
import context
import signal

const MONITOR_MAX_DUR = 1 # second
const SAMPLE_RATES = [48000, 44100, 96000, 24000]
const SAMPLE_FORMAT = SoundIoFormatFloat32NE

type
  SoundSystem* = object
    sio*: ptr SoundIo
    inDevice*: ptr SoundIoDevice
    outDevice*: ptr SoundIoDevice
  IOStream* = object
    inStream*: ptr SoundIoInStream
    outStream*: ptr SoundIoOutStream
    userdata: ptr UserData
  UserData = object
    context: Context
    signal: Signal
    monitor: ptr SoundIoRingBuffer
    input: ptr SoundIoRingBuffer

let sizeOfChannelArea = sizeof SoundIoChannelArea
let sizeOfSample = sizeof float

proc writeCallback(outStream: ptr SoundIoOutStream, frameCountMin: cint, frameCountMax: cint) {.cdecl.} =
  let userdata = cast[ptr UserData](outStream.userdata)
  let monitor = userdata.monitor
  let input = userdata.input
  let ctx = userdata.context
  let signal = userdata.signal.f
  let channelCount = outStream.layout.channelCount
  var areas: ptr SoundIoChannelArea
  var framesLeft = frameCountMax
  var err: cint

  while true:
    var frameCount = framesLeft

    err = outStream.beginWrite(areas.addr, frameCount.addr)
    if err > 0:
      quit "Unrecoverable out stream begin error: " & $err.strerror
    if frameCount <= 0:
      break

    let ptrAreas = cast[int](areas)
    let ptrMonitor = cast[int](monitor.writePtr)
    var ptrInput: int
    if not input.isNil:
      ptrInput = cast[int](input.readPtr)

    for frame in 0..<frameCount:
      let offset = frame * channelCount
      for channel in 0..<channelCount:
        ctx.channel = channel
        if not input.isNil:
          ctx.input = cast[ptr float](ptrInput + (offset + channel) * sizeOfSample)[]

        let ptrArea = cast[ptr SoundIoChannelArea](ptrAreas + channel*sizeOfChannelArea)
        var ptrSample = cast[ptr float32](cast[int](ptrArea.pointer) + frame*ptrArea.step)
        let sample = signal(ctx)
        ptrSample[] = sample.float32

        when not defined(windows):
          var ptrMonitorSample = cast[ptr float](ptrMonitor + (offset + channel) * sizeOfSample)
          ptrMonitorSample[] = sample
      ctx.sampleNumber += 1

    let bytesProcessed = cint(frameCount * channelCount * sizeOfSample)
    monitor.advanceWritePtr(bytesProcessed)
    if not input.isNil:
      input.advanceReadPtr(bytesProcessed)

    err = outStream.endWrite
    if err > 0 and err != cint(SoundIoError.Underflow):
      quit "Unrecoverable out stream end error: " & $err.strerror

    framesLeft -= frameCount
    if framesLeft <= 0:
      break

proc readCallback(inStream: ptr SoundIoInStream, frameCountMin: cint, frameCountMax: cint) {.cdecl.} =
  let channelCount = inStream.layout.channelCount
  let userdata = cast[ptr UserData](inStream.userdata)
  let buffer = userdata.input
  let writePtr = cast[int](buffer.writePtr)
  let freeBytes = buffer.freeCount
  # NOTE max(frameCountMin, ...) masks ring buffer overflows
  # which may lead to unexpected shifts while reading,
  # we might want to reconsider this behaviour
  let freeCount = max(frameCountMin, freeBytes div (channelCount * sizeOfSample))

  let writeFrames = min(freeCount, frameCountMax)
  var framesLeft: cint = cast[cint](writeFrames)
  var areas: ptr SoundIoChannelArea
  var err: cint

  while true:
    var frameCount = framesLeft

    err = inStream.beginRead(areas.addr, frameCount.addr)
    if err > 0:
      quit "Unrecoverable in stream begin error: " & $err.strerror
    if frameCount <= 0:
      break

    if areas.isNil:
      # Due to an overflow there is a hole. Fill the ring buffer with silence for the size of the hole.
      for frame in 0..<frameCount:
        let offset = frame * channelCount
        for channel in 0..<channelCount:
          var ptrBufferSample = cast[ptr float](writePtr + (offset + channel) * sizeOfSample)
          ptrBufferSample[] = 0.0
    else:
      let ptrAreas = cast[int](areas)
      for frame in 0..<frameCount:  
        let offset = frame * channelCount
        for channel in 0..<channelCount:
          let ptrArea = cast[ptr SoundIoChannelArea](ptrAreas + channel*sizeOfChannelArea)
          var ptrSample = cast[ptr float32](cast[int](ptrArea.pointer) + frame*ptrArea.step)
          let sample: float = ptrSample[]
          var ptrBufferSample = cast[ptr float](writePtr + (offset + channel) * sizeOfSample)
          ptrBufferSample[] = sample

    buffer.advanceWritePtr(cint(frameCount * channelCount * sizeOfSample))

    err = inStream.endRead
    if err > 0:
      quit "Unrecoverable in stream end error: " & $err.strerror

    framesLeft -= frameCount
    if framesLeft <= 0:
      break

proc sserr(msg: string): Result[SoundSystem] =
  return Result[SoundSystem](kind: Err, msg: msg)

proc ioserr(msg: string): Result[IOStream] =
  return Result[IOStream](kind: Err, msg: msg)

proc newSoundSystem*(withInput: bool): Result[SoundSystem] =
  let sio = soundioCreate()
  if sio.isNil:
    return sserr "out of mem"

  var err = sio.connect
  if err > 0:
    return sserr "Unable to connect to backend: " & $err.strerror

  echo "Backend: \t", sio.currentBackend.name
  sio.flushEvents

  var inDevice: ptr SoundIoDevice
  if withInput:
    let inDevId = sio.defaultInputDeviceIndex
    if inDevId < 0:
      return sserr "Input device is not found"
    inDevice = sio.getInputDevice(inDevId)
    if inDevice.isNil:
      return sserr "out of mem"
    if inDevice.probeError > 0:
      return sserr "Cannot probe device"

    echo "Input device:\t", inDevice.name

  let outDevId = sio.defaultOutputDeviceIndex
  if outDevId < 0:
    return sserr "Output device is not found"
  let outDevice = sio.getOutputDevice(outDevId)
  if outDevice.isNil:
    return sserr "out of mem"
  if outDevice.probeError > 0:
    return sserr "Cannot probe device"

  echo "Output device:\t", outDevice.name

  return Result[SoundSystem](
    kind: Ok,
    value: SoundSystem(sio: sio, inDevice: inDevice, outDevice: outDevice))

proc newIOStream*(ss: SoundSystem, withInput: bool): Result[IOStream] =
  ss.outDevice.sortChannelLayouts
  var layout: ptr SoundIoChannelLayout

  if withInput:
    layout = bestMatchingChannelLayout(
      ss.outDevice.layouts, ss.outDevice.layoutCount,
      ss.inDevice.layouts, ss.inDevice.layoutCount,
    )
  else:
    layout = bestMatchingChannelLayout(
      ss.outDevice.layouts, ss.outDevice.layoutCount,
      ss.outDevice.layouts, ss.outDevice.layoutCount,
    )

  if layout.isNil:
    return ioserr "Channel layouts not compatible"

  var sampleRate: cint
  for sr in SAMPLE_RATES:
    let csr = cast[cint](sr)
    if withInput:
      if ss.inDevice.supportsSampleRate(csr) and ss.outDevice.supportsSampleRate(csr):
        sampleRate = csr
        break
    else:
      if ss.outDevice.supportsSampleRate(csr):
        sampleRate = csr
        break

  if sampleRate == 0:
    return ioserr "Incompatible sound rates"

  var err: cint
  var inStream: ptr SoundIoInStream
  if withInput:
    inStream = ss.inDevice.inStreamCreate
    inStream.format = SAMPLE_FORMAT
    inStream.sampleRate = sampleRate
    inStream.layout = layout[]
    inStream.readCallback = readCallback

    err = inStream.open
    if err > 0:
      return ioserr "Unable to open input device: " & $err.strerror

    if inStream.layoutError > 0:
      return ioserr "Unable to set input channel layout: " & $inStream.layoutError.strerror

  let outStream = ss.outDevice.outStreamCreate
  outStream.format = SAMPLE_FORMAT
  outStream.sampleRate = sampleRate
  outStream.layout = layout[]
  outStream.writeCallback = writeCallback

  err = outStream.open
  if err > 0:
    return ioserr "Unable to open output device: " & $err.strerror

  if outStream.layoutError > 0:
    return ioserr "Unable to set output channel layout: " & $outStream.layoutError.strerror

  let ptrUserdata = UserData.sizeof.alloc
  if withInput:
    inStream.userdata = ptrUserdata
  outStream.userdata = ptrUserdata

  var ctx = Context(
    channel: 0,
    sampleNumber: 0,
    sampleRate: sampleRate,
    sampleRateFloat: sampleRate.toFloat,
    sampleDuration: 1.0 / sampleRate.toFloat
  )
  var silence = 0.toSignal

  GC_ref ctx
  GC_ref silence

  var userdata = cast[ptr UserData](ptrUserdata)
  userdata.context = ctx
  userdata.signal = silence
  userdata.monitor = ss.sio.ringBufferCreate(cast[cint](
    MONITOR_MAX_DUR * sampleRate * layout.channelCount * sizeOfSample
  ))
  if withInput:
    userdata.input = ss.sio.ringBufferCreate(cast[cint]((
      inStream.softwareLatency * (4 * sampleRate * layout.channelCount * sizeOfSample).toFloat
    ).toInt))

  if withInput:
    err = inStream.start
    if err > 0:
      return ioserr "Unable to start input stream: " & $err.strerror

  err = outStream.start
  if err > 0:
    return ioserr "Unable to start output stream: " & $err.strerror

  return Result[IOStream](kind: Ok, value: IOStream(inStream: inStream, outStream: outStream, userdata: userdata))

proc `=destroy`(s: var SoundSystem) =
  s.inDevice.unref
  s.outDevice.unref
  s.sio.destroy

proc `=destroy`(s: var IOStream) =
  s.inStream.destroy
  s.outStream.destroy
  GC_unref s.userdata.signal
  GC_unref s.userdata.context
  s.userdata.monitor.destroy
  s.userdata.input.destroy
  s.userdata.dealloc

proc `signal=`*(stream: IOStream, s: Signal) =
  GC_unref stream.userdata.signal
  stream.userdata.signal = s
  GC_ref stream.userdata.signal

proc signal*(stream: IOStream): Signal = stream.userdata.signal

proc context*(stream: IOStream): Context =
  result.deepCopy(stream.userdata.context)

proc monitor*(stream: IOStream): ptr SoundIoRingBuffer = stream.userdata.monitor
