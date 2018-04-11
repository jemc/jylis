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
  let _core: RepoManagerCore[RepoSYSTEM, RepoSYSTEMHelp]
  
  new create(config': Config) =>
    _config = config'
    _core   = _core.create("SYSTEM", _config.addr.hash())
  
  be apply(resp: Respond, cmd: Array[String] val) =>
    _core(resp, cmd)
  
  be flush_deltas(fn: _SendDeltasFn) =>
    _core.flush_deltas(fn)
  
  be converge_deltas(deltas: Array[(String, Any box)] val) =>
    _core.converge_deltas(deltas)
  
  be clean_shutdown(promise: Promise[None]) =>
    _core.clean_shutdown(promise)
  
  ///
  // System private methods, meant for use only within the jylis server.
  // Generally, the purpose is to fill data that is read-only to the user.
  
  be log(string: String) => _core.repo()._inslog(string, Time.millis())

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
