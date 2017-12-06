use "collections"
use "crdt"
use "resp"

class RepoGCOUNT
  let _identity: U64
  let _data:   Map[String, GCounter] = _data.create()
  let _deltas: Map[String, GCounter] = _deltas.create()
  
  new create(identity': U64) => _identity = identity'
  
  fun deltas(): Map[String, GCounter] box => _deltas
  fun ref clear_deltas() => _deltas.clear()
  
  fun ref apply(r: Respond, cmd: Iterator[String])? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "ADD" => add(r, _key(cmd)?, _value(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try
      let delta = delta' as GCounter box
      try _data(key)?.converge(delta)
      else _data(key) = GCounter(_identity).>converge(delta)
      end
    end
  
  fun get(resp: Respond, key: String) =>
    resp.u64(try _data(key)?.value() else 0 end)
  
  fun ref add(resp: Respond, key: String, value: U64) =>
    let delta =
      try _deltas(key)? else
        let d = GCounter(_identity)
        _deltas(key) = d
        d
      end
    
    try _data(key)?.increment(value, delta)
    else _data(key) = GCounter(_identity).>increment(value, delta)
    end
    
    resp.ok() // Consider issuing an error when "node-local value" overflows? (remember to update docs)
