use "collections"
use "crdt"
use "resp"

primitive RepoTREGHelp is HelpLeaf
  fun datatype(): String => "TREG"
  fun commands(map: Map[String, String]) =>
    map("GET") = "key"
    map("SET") = "key value timestamp"

class RepoTREG
  let _data:   Map[String, TRegString] = _data.create()
  let _deltas: Map[String, TRegString] = _deltas.create()
  
  new ref create(identity': U64) => None
  
  fun ref deltas_size(): USize => _deltas.size()
  fun ref flush_deltas(): Array[(String, Any box)] box =>
    let out = Array[(String, Any box)](_deltas.size())
    for (k, d) in _deltas.pairs() do out.push((k, d)) end
    _deltas.clear()
    out
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "SET" => set(r, _key(cmd)?, _value(cmd)?, _timestamp(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _timestamp(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun ref _data_for(key: String): TRegString =>
    try _data(key)? else
      let d = TRegString
      _data(key) = d
      d
    end
  
  fun ref _delta_for(key: String): TRegString =>
    try _deltas(key)? else
      let d = TRegString
      _deltas(key) = d
      d
    end
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try _data_for(key).converge(delta' as TRegString box) end
  
  fun get(resp: Respond, key: String): Bool =>
    try
      let reg = _data(key)?
      resp.array_start(2)
      resp.string(reg.value())
      resp.u64(reg.timestamp())
    else
      resp.null()
    end
    false
  
  fun ref set(resp: Respond, key: String, value: String, timestamp: U64): Bool =>
    _data_for(key).update(value, timestamp, _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
