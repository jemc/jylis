use "collections"
use "crdt"
use "resp"

primitive RepoTLOGHelp is HelpLeaf
  fun datatype(): String => "TLOG"
  fun commands(map: Map[String, String]) =>
    map("GET")    = "key [count]"
    map("INS")    = "key value timestamp"
    map("SIZE")   = "key"
    map("CUTOFF") = "key"
    map("TRIMAT") = "key timestamp"
    map("TRIM")   = "key count"

class RepoTLOG
  let _data:   Map[String, TLog[String]] = _data.create()
  let _deltas: Map[String, TLog[String]] = _deltas.create()
  
  new ref create(identity': U64) => None
  
  fun ref deltas_size(): USize => _deltas.size()
  fun ref flush_deltas(): Array[(String, Any box)] box =>
    let out = Array[(String, Any box)](_deltas.size())
    for (k, d) in _deltas.pairs() do out.push((k, d)) end
    _deltas.clear()
    out
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GET"    => get(r, _key(cmd)?, _opt_count(cmd))
    | "INS"    => ins(r, _key(cmd)?, _value(cmd)?, _timestamp(cmd)?)
    | "SIZE"   => size(r, _key(cmd)?)
    | "CUTOFF" => cutoff(r, _key(cmd)?)
    | "TRIMAT" => trimat(r, _key(cmd)?, _timestamp(cmd)?)
    | "TRIM"   => trim(r, _key(cmd)?, _count(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _timestamp(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun tag _count(cmd: Iterator[String]): USize? => cmd.next()?.usize()?
  
  fun tag _opt_count(cmd: Iterator[String]): USize =>
    try cmd.next()?.usize()? else -1 end
  
  fun ref _data_for(key: String): TLog[String] =>
    try _data(key)? else
      let d = TLog[String](0)
      _data(key) = d
      d
    end
  
  fun ref _delta_for(key: String): TLog[String] =>
    try _deltas(key)? else
      let d = TLog[String](0)
      _deltas(key) = d
      d
    end
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try _data_for(key).converge(delta' as TLog[String] box) end
  
  fun get(resp: Respond, key: String, count: USize): Bool =>
    try
      let log   = _data(key)?
      var total = log.size().min(count)
      resp.array_start(total)
      for (value, timestamp) in log.entries() do
        if 0 == (total = total - 1) then break end
        resp.array_start(2)
        resp.string(value)
        resp.u64(timestamp)
      end
    else
      resp.array_start(0)
    end
    false
  
  fun ref ins(resp: Respond, key: String, value: String, timestamp: U64): Bool =>
    _data_for(key).write(value, timestamp, _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun size(resp: Respond, key: String): Bool =>
    resp.u64(try _data(key)?.size().u64() else 0 end)
    false
  
  fun cutoff(resp: Respond, key: String): Bool =>
    resp.u64(try _data(key)?.cutoff() else 0 end)
    false
  
  fun ref trimat(resp: Respond, key: String, timestamp: U64): Bool =>
    _data_for(key).raise_cutoff(timestamp, _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref trim(resp: Respond, key: String, count: USize): Bool =>
    _data_for(key).trim(count, _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
