import audio/[context, signal]
import environment
import locks
import triggers
import samplers
import sndfile
import tables
import times
import sequtils

# TODO better error handling
proc loadSampler*(path: string): Sampler =
  let ptrInfo = SF_INFO.sizeof.alloc
  var info = cast[ptr SF_INFO](ptrInfo)
  info.format = 0
  let h = path.sf_open(SFM_READ, info)
  if h.isNil:
    echo "failed to open file"
    return
  let ptrBuffer = (info.frames * info.channels * cdouble.sizeof).alloc
  let channels = info.channels
  let frames = h.sf_readf_double(cast[ptr cdouble](ptrBuffer), info.frames)
  # TODO resampling, channels
  result = Sampler(table: newSeq[float](frames * channels))
  for frame in 0..<frames:
    for channel in 0..<channels:
      let i = (channel + frame * channels).int
      let offset = cast[int](ptrBuffer) + i * cdouble.sizeof
      result.table[i] = cast[ptr cdouble](offset)[]
  ptrBuffer.dealloc
  ptrInfo.dealloc
  discard h.sf_close


proc saveSampler*(env: Environment, sampler: Sampler, path: string) =
  let frames = sampler.table.len div MAX_CHANNELS
  let channels = env.channelCount
  let ptrInfo = SF_INFO.sizeof.alloc
  var info = cast[ptr SF_INFO](ptrInfo)
  info.frames = frames
  info.samplerate = cast[cint](env.sampleRate)
  info.channels = cast[cint](channels)
  info.format = SF_FORMAT_WAV or SF_FORMAT_PCM_24
  let h = path.sf_open(SFM_WRITE, info)
  if h.isNil:
    echo "failed to open file"
    return
  let ptrBuffer = (frames * channels * cdouble.sizeof).alloc
  for frame in 0..<frames:
    for channel in 0..<channels:
      let i = (channel + frame * channels).int
      let offset = cast[int](ptrBuffer) + i * cdouble.sizeof
      cast[ptr cdouble](offset)[] = sampler.table[i] 
  discard h.sf_writef_double(cast[ptr cdouble](ptrBuffer), frames)
  ptrBuffer.dealloc
  ptrInfo.dealloc
  discard h.sf_close
