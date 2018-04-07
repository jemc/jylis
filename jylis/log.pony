use "logger"
use "inspect"

primitive _LogOutStreamNone
  fun tag print(data: ByteSeq) => None
  fun tag write(data: ByteSeq) => None
  fun tag printv(data: ByteSeqIter) => None
  fun tag writev(data: ByteSeqIter) => None

class val Log
  let _log: Logger[String]
  new val create_fine(out: OutStream) => _log = StringLogger(Fine, out)
  new val create_info(out: OutStream) => _log = StringLogger(Info, out)
  new val create_warn(out: OutStream) => _log = StringLogger(Warn, out)
  new val create_err(out: OutStream) => _log = StringLogger(Error, out)
  new val create_none() => _log = StringLogger(Error, _LogOutStreamNone)
  
  fun fine(): Bool => _log(Fine)
  fun info(): Bool => _log(Info)
  fun warn(): Bool => _log(Warn)
  fun err(): Bool => _log(Error)
  
  fun apply(
    a: Any box,
    b: Any box = None,
    c: Any box = None,
    d: Any box = None)
    : Bool
  =>
    let out = recover trn String end
    out.append(Inspect(a))
    if b isnt None then out.>push(';').>push(' ').append(Inspect(b)) end
    if c isnt None then out.>push(';').>push(' ').append(Inspect(c)) end
    if d isnt None then out.>push(';').>push(' ').append(Inspect(d)) end
    _log.log(consume out)
    true
