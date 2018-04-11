use "logger"
use "inspect"

primitive _LogOutStreamNone
  fun tag print(data: ByteSeq) => None
  fun tag write(data: ByteSeq) => None
  fun tag printv(data: ByteSeqIter) => None
  fun tag writev(data: ByteSeqIter) => None

class val Log
  let _addr: String
  let _out: OutStream
  let _level: LogLevel
  
  new val create_debug(addr': Address, out': OutStream) =>
    (_level, _addr, _out) = (Fine, addr'.string(), out')
  
  new val create_info(addr': Address, out': OutStream) =>
    (_level, _addr, _out) = (Info, addr'.string(), out')
  
  new val create_warn(addr': Address, out': OutStream) =>
    (_level, _addr, _out) = (Warn, addr'.string(), out')
  
  new val create_err(addr': Address, out': OutStream) =>
    (_level, _addr, _out) = (Error, addr'.string(), out')
  
  new val create_none() =>
    (_addr, _level, _out) = ("", Error, _LogOutStreamNone)
  
  fun debug(): Bool => _level() <= Fine()
  fun info(): Bool => _level() <= Info()
  fun warn(): Bool => _level() <= Warn()
  fun err(): Bool => _level() <= Error()
  
  fun d(string: String, loc: SourceLoc = __loc): Bool => _log('D', string, loc)
  fun i(string: String, loc: SourceLoc = __loc): Bool => _log('I', string, loc)
  fun w(string: String, loc: SourceLoc = __loc): Bool => _log('W', string, loc)
  fun e(string: String, loc: SourceLoc = __loc): Bool => _log('E', string, loc)
  
  fun _log(level: U8, string: String, loc: SourceLoc): Bool =>
    let buf = recover trn String(5 + _addr.size() + string.size()) end
    buf
      .> append(_addr)
      .> push(' ') .> push('(') .> push(level) .> push(')') .> push(' ')
      .> append(string)
    _out.print(consume buf)
    true
  
  fun inspect(
    x1: Any box,
    x2: Any box = None,
    x3: Any box = None,
    x4: Any box = None,
    loc: SourceLoc = __loc)
    : Bool
  =>
    let out = recover trn String end
    out.append(Inspect(x1))
    if x2 isnt None then out.>push(';').>push(' ').append(Inspect(x2)) end
    if x3 isnt None then out.>push(';').>push(' ').append(Inspect(x3)) end
    if x4 isnt None then out.>push(';').>push(' ').append(Inspect(x4)) end
    _log('D', consume out, loc)
    true
