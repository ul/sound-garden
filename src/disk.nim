import environment
import sndfile
import tables
import sequtils

# TODO better error handling
proc loadTable*(env: Environment; key, path: string) =
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
  echo channels, "x", frames
  # TODO resampling, channels
  let sampler = Sampler(table: newSeq[float](frames * channels))
  for frame in 0..<frames:
    for channel in 0..<channels:
      let i = (channel + frame * channels).int
      let offset = cast[int](ptrBuffer) + i * cdouble.sizeof
      sampler.table[i] = cast[ptr cdouble](offset)[]
  env.samplers[key] = sampler
  ptrBuffer.dealloc
  ptrInfo.dealloc
  discard h.sf_close
