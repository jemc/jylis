use "collections"
use "crdt"
use "resp"

primitive RepoUJSONHelp is HelpRepo
  fun datatype(): String => "UJSON"
  fun commands(map: Map[String, String]) =>
    map("GET") = "key [key...]"
    map("SET") = "key [key...] ujson"
    map("CLR") = "key [key...]"
    map("INS") = "key [key...] value"
    map("RM")  = "key [key...] value"

class RepoUJSON
  let _identity: U64
  let _data:   Map[String, UJSON] = _data.create()
  let _deltas: Map[String, UJSON] = _deltas.create()
  
  new create(identity': U64) => _identity = identity'
  
  fun ref deltas_size(): USize => _deltas.size()
  fun ref flush_deltas(): Array[(String, Any box)] box =>
    let out = Array[(String, Any box)](_deltas.size())
    for (k, d) in _deltas.pairs() do out.push((k, d)) end
    _deltas.clear()
    out
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?, _rest(cmd))
    | "SET" => set(r, _key(cmd)?, _rest_but_last(cmd)?)?
    | "CLR" => clr(r, _key(cmd)?, _rest(cmd))
    | "INS" => ins(r, _key(cmd)?, _rest_but_last(cmd)?)?
    | "RM"  => rm(r, _key(cmd)?, _rest_but_last(cmd)?)?
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _rest(cmd: Iterator[String]): Array[String] val =>
    let out = recover Array[String] end
    for str in cmd do out.push(str) end
    out
  
  fun tag _rest_but_last(cmd: Iterator[String]): (Array[String] val, String)? =>
    let out = recover Array[String] end
    for str in cmd do out.push(str) end
    let last = out.pop()?
    (consume out, last)
  
  fun ref _data_for(key: String): UJSON =>
    try _data(key)? else
      let d = UJSON(_identity)
      _data(key) = d
      d
    end
  
  fun ref _delta_for(key: String): UJSON =>
    try _deltas(key)? else
      let d = UJSON(0)
      _deltas(key) = d
      d
    end
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try _data_for(key).converge(delta' as UJSON box) end
  
  fun get(resp: Respond, key: String, path: Array[String] val): Bool =>
    try resp.string(_data(key)?.get(path).string())
    else resp.string("")
    end
    false
  
  fun ref set(
    resp: Respond,
    key: String,
    pathvalue: (Array[String] val, String))
  : Bool? =>
    (let path, let value) = pathvalue
    let node = UJSONParse.node(value)?
    _data_for(key).put(path, node, _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref clr(resp: Respond, key: String, path: Array[String] val): Bool =>
    try _data(key)?.clear(path, _delta_for(key)).string() end
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref ins(
    resp: Respond,
    key: String,
    pathvalue: (Array[String] val, String))
  : Bool? =>
    (let path, let value) = pathvalue
    let value' = UJSONParse.value(value)?
    _data_for(key).insert(path, value', _delta_for(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref rm(
    resp: Respond,
    key: String,
    pathvalue: (Array[String] val, String))
  : Bool? =>
    (let path, let value) = pathvalue
    let value' = UJSONParse.value(value)?
    try _data(key)?.remove(path, value', _delta_for(key)) end
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
