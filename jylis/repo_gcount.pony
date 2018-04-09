use "collections"
use "crdt"
use "resp"

primitive RepoGCOUNTHelp is HelpLeaf
  fun datatype(): String => "GCOUNT"
  fun commands(map: Map[String, String]) =>
    map("GET") = "key"
    map("INC") = "key value"

class RepoGCOUNT
  let _identity: U64
  let _data:   Map[String, GCounter] = _data.create()
  let _deltas: Map[String, GCounter] = _deltas.create()
  
  new create(identity': U64) => _identity = identity'
  
  fun ref deltas_size(): USize => _deltas.size()
  fun ref flush_deltas(): Array[(String, Any box)] box =>
    let out = Array[(String, Any box)](_deltas.size())
    for (k, d) in _deltas.pairs() do out.push((k, d)) end
    _deltas.clear()
    out
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "INC" => inc(r, _key(cmd)?, _value(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun ref _data_for(key: String): GCounter =>
    try _data(key)? else
      let d = GCounter(_identity)
      _data(key) = d
      d
    end
  
  fun ref _delta_for(key: String): GCounter =>
    try _deltas(key)? else
      let d = GCounter(0)
      _deltas(key) = d
      d
    end
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try _data_for(key).converge(delta' as GCounter box) end
  
  fun get(resp: Respond, key: String): Bool =>
    resp.u64(try _data(key)?.value() else 0 end)
    false
  
  fun ref inc(resp: Respond, key: String, value: U64): Bool =>
    _data_for(key).increment(value, _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
