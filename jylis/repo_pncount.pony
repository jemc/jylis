use "collections"
use "crdt"
use "resp"

primitive RepoPNCOUNTHelp is HelpLeaf
  fun datatype(): String => "PNCOUNT"
  fun commands(map: Map[String, String]) =>
    map("GET") = "key"
    map("INC") = "key value"
    map("DEC") = "key value"

class RepoPNCOUNT
  let _identity: U64
  let _data:   Map[String, PNCounter] = _data.create()
  let _deltas: Map[String, PNCounter] = _deltas.create()
  
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
    | "DEC" => dec(r, _key(cmd)?, _value(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): I64? => cmd.next()?.i64()?
  
  fun ref _data_for(key: String): PNCounter =>
    try _data(key)? else
      let d = PNCounter(_identity)
      _data(key) = d
      d
    end
  
  fun ref _delta_for(key: String): PNCounter =>
    try _deltas(key)? else
      let d = PNCounter(0)
      _deltas(key) = d
      d
    end
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try _data_for(key).converge(delta' as PNCounter box) end
  
  fun get(resp: Respond, key: String): Bool =>
    resp.i64(try _data(key)?.value().i64() else 0 end)
    false
  
  fun ref inc(resp: Respond, key: String, value: I64): Bool =>
    _data_for(key).increment(value.u64(), _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref dec(resp: Respond, key: String, value: I64): Bool =>
    _data_for(key).decrement(value.u64(), _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
