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
  let _data:  CKeyspace[String, UJSON]
  var _delta: CKeyspace[String, UJSON] = _delta.create(0)
  
  new create(identity: U64) => _data = _data.create(identity)
  
  fun ref delta_empty(): Bool => _delta.is_empty()
  fun ref flush_deltas(): Tokens => Tokens .> from(_delta = _delta.create(0))
  fun ref converge(tokens: TokensIterator)? =>
    _data.converge(_delta.create(0) .> from_tokens(tokens)?)
  
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
    _data.at(key).put(path, node, _delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref clr(resp: Respond, key: String, path: Array[String] val): Bool =>
    try _data(key)?.clear_at(path, _delta.at(key)) end
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref ins(
    resp: Respond,
    key: String,
    pathvalue: (Array[String] val, String))
  : Bool? =>
    (let path, let value) = pathvalue
    let value' = UJSONParse.value(value)?
    _data.at(key).insert(path, value', _delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref rm(
    resp: Respond,
    key: String,
    pathvalue: (Array[String] val, String))
  : Bool? =>
    (let path, let value) = pathvalue
    let value' = UJSONParse.value(value)?
    try _data(key)?.remove(path, value', _delta.at(key)) end
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
