use "collections"
use "crdt"
use "resp"

primitive RepoSYSTEMHelp is HelpLeaf
  fun apply(cmd: Iterator[String]): String =>
    """
    The following are valid SYSTEM commands:
      SYSTEM GETLOG [count]
    """

class RepoSYSTEM
  let _identity: U64
  
  let _log:       TLog[String] = TLog[String]
  var _log_delta: TLog[String] = TLog[String]
  
  new create(identity': U64) => _identity = identity'
  
  fun ref deltas_size(): USize => 1
  fun ref flush_deltas(): Array[(String, Any box)] box =>
    let out = Array[(String, Any box)](deltas_size())
    out.push(("_log", _log_delta = _log_delta.create()))
    out
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    match key
    | "_log" => try _log.converge(delta' as TLog[String] box) end
    end
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GETLOG" => getlog(r, _optcount(cmd))
    else error
    end
  
  fun tag _optcount(cmd: Iterator[String]): USize =>
    try cmd.next()?.usize()? else -1 end
  
  fun ref getlog(resp: Respond, count: USize): Bool =>
    var total = _log.size().min(count)
    resp.array_start(total)
    for (value, timestamp) in _log.entries() do
      if 0 == (total = total - 1) then break end
      resp.array_start(2)
      resp.string(value)
      resp.u64(timestamp)
    end
    false
  
  ///
  // System private methods, meant for use only within the jylis server.
  // Generally, the purpose is to fill data that is read-only to the user.
  
  fun ref _inslog(value: String, timestamp: U64) =>
    _log.write(value, timestamp, _log_delta)
  
  fun ref _trimlog(count: USize) =>
    _log.trim(count)
