use "collections"
use "crdt"
use "resp"

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
  
  fun ref apply(r: Respond, cmd: Iterator[String])? =>
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
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try
      let delta = delta' as UJSON box
      try _data(key)?.converge(delta)
      else _data(key) = UJSON(_identity).>converge(delta)
      end
    end
  
  fun get(resp: Respond, key: String, path: Array[String] val) =>
    try resp.string(_data(key)?.get(path).string())
    else resp.string("")
    end
  
  fun ref set(
    resp: Respond,
    key: String,
    pathvalue: (Array[String] val, String))
  ? =>
    let delta =
      try _deltas(key)? else
        let d = UJSON(_identity)
        _deltas(key) = d
        d
      end
    
    (let path, let value) = pathvalue
    let node = UJSONParse.node(value)?
    try _data(key)?.put(path, node, delta)
    else _data(key) = UJSON(_identity).>put(path, node, delta)
    end
    
    resp.ok()
  
  fun ref clr(resp: Respond, key: String, path: Array[String] val) =>
    try _data(key)?.clear(path).string() end
    resp.ok()
  
  fun ref ins(
    resp: Respond,
    key: String,
    pathvalue: (Array[String] val, String))
  ? =>
    let delta =
      try _deltas(key)? else
        let d = UJSON(_identity)
        _deltas(key) = d
        d
      end
    
    (let path, let value) = pathvalue
    let value' = UJSONParse.value(value)?
    try _data(key)?.insert(path, value', delta)
    else _data(key) = UJSON(_identity).>insert(path, value', delta)
    end
    
    resp.ok()
  
  fun ref rm(
    resp: Respond,
    key: String,
    pathvalue: (Array[String] val, String))
  ? =>
    let delta =
      try _deltas(key)? else
        let d = UJSON(_identity)
        _deltas(key) = d
        d
      end
    
    (let path, let value) = pathvalue
    let value' = UJSONParse.value(value)?
    try _data(key)?.remove(path, value', delta)
    else _data(key) = UJSON(_identity).>remove(path, value', delta)
    end
    
    resp.ok()
