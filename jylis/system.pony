use "crdt"
use "resp"
use "time"
use "promises"

class val System
  let _sys: _System
  new val create(config': Config) => _sys = _System(config')
  
  fun log(string: String) => _sys.log(string)
  fun fork_logs_from(fork: SystemLogFork) => fork(_sys)
  
  fun repo(): RepoManagerAny => _sys

actor _System is RepoManagerAny
  let _config: Config
  let _log: TLog[String] = TLog[String]
  
  new create(config': Config) => _config = config'
  
  be log(string: String) => _log.write(string, Time.millis())
  
  be apply(resp: Respond, cmd': Array[String] val) =>
    let cmd = cmd'.values()
    try
      cmd.next()? // discard first word; it was already read to route us here
      match cmd.next()?
      | "GETLOG" => _getlog(resp, _optcount(cmd))
      else error
      end
    else
      HelpRespond(resp,
        """
        The following are valid SYSTEM commands:
          SYSTEM GETLOG [count]
        """)
    end
  
  fun tag _optcount(cmd: Iterator[String]): USize =>
    try cmd.next()?.usize()? else -1 end
  
  fun ref _getlog(resp: Respond, count: USize): Bool =>
    var total = _log.size().min(count)
    resp.array_start(total)
    for (value, timestamp) in _log.entries() do
      if 0 == (total = total - 1) then break end
      resp.array_start(2)
      resp.string(value)
      resp.u64(timestamp)
    end
    false
  
  be flush_deltas(fn: _SendDeltasFn) => // TODO: use actual deltas instead of full state
    fn(("SYSTEM", [("LOG", _log)]))
  
  be converge_deltas(deltas: Array[(String, Any box)] val) =>
    for (key, delta) in deltas.values() do
      match key
      | "LOG" => try _log.converge(delta as TLog[String] box) end
      end
    end
  
  be clean_shutdown(promise: Promise[None]) => promise(None) // TODO

actor SystemLogFork
  let _a: OutStream
  var _sys: (_System | None) = None
  
  new create(a': OutStream) => _a = a'
  
  be apply(sys': _System) => _sys = sys'
  
  fun tag _string(data': ByteSeq): String =>
    match data'
    | let data: Array[U8] val => String.from_array(data)
    | let data: String => data
    end
  
  be print(data: ByteSeq) =>
    _a.print(data)
    try (_sys as _System).log(_string(data)) end
  
  be write(data: ByteSeq) =>
    _a.write(data)
    try (_sys as _System).log(_string(data)) end
  
  be printv(data: ByteSeqIter) =>
    _a.printv(data)
    try
      let sys = _sys as _System
      for bytes in data.values() do
        sys.log(_string(bytes))
      end
    end
  
  be writev(data: ByteSeqIter) =>
    _a.writev(data)
    try
      let sys = _sys as _System
      for bytes in data.values() do
        sys.log(_string(bytes))
      end
    end
