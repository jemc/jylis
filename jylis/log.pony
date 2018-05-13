use "logger"
use "inspect"

primitive _LogOutStreamNone
  fun tag print(data: ByteSeq) => None
  fun tag write(data: ByteSeq) => None
  fun tag printv(data: ByteSeqIter) => None
  fun tag writev(data: ByteSeqIter) => None

class val Log
  let _level: LogLevel
  let _log: _Log
  
  new val create_debug(out': OutStream) =>
    (_level, _log) = (Fine, _Log(out'))
  
  new val create_info(out': OutStream) =>
    (_level, _log) = (Info, _Log(out'))
  
  new val create_warn(out': OutStream) =>
    (_level, _log) = (Warn, _Log(out'))
  
  new val create_err(out': OutStream) =>
    (_level, _log) = (Error, _Log(out'))
  
  new val create_none() =>
    (_level, _log) = (Error, _Log(_LogOutStreamNone))
  
  fun set_sys(sys': SystemRepoManager) => _log.set_sys(sys')
  
  fun debug(): Bool => _level() <= Fine()
  fun info(): Bool => _level() <= Info()
  fun warn(): Bool => _level() <= Warn()
  fun err(): Bool => _level() <= Error()
  
  fun d(string: String, loc: SourceLoc = __loc): Bool =>
    _log('D', string, loc)
    true
  
  fun i(string: String, loc: SourceLoc = __loc): Bool =>
    _log('I', string, loc)
    true
  
  fun w(string: String, loc: SourceLoc = __loc): Bool =>
    _log('W', string, loc)
    true
  
  fun e(string: String, loc: SourceLoc = __loc): Bool =>
    _log('E', string, loc)
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

actor _Log
  let _out: OutStream
  var _sys: (SystemRepoManager | None) = None
  
  new create(out': OutStream) => _out = out'
  be set_sys(sys': SystemRepoManager) => _sys = sys'
  
  be apply(level: U8, string: String, loc: SourceLoc) =>
    let buf =
      recover val
        String(4 + string.size())
          .> push('(') .> push(level) .> push(')') .> push(' ')
          .> append(string)
      end
    
    if level != 'D' then // skip debug-level logs in distributed system log
      try (_sys as SystemRepoManager).log(buf) end
    end
    
    _out.print(buf)
