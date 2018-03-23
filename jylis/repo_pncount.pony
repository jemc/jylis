use "collections"
use "crdt"
use "resp"

class RepoPNCOUNT
  let _identity: U64
  let _data:   Map[String, PNCounter] = _data.create()
  let _deltas: Map[String, PNCounter] = _deltas.create()
  
  new create(identity': U64) => _identity = identity'
  
  fun deltas(): Map[String, PNCounter] box => _deltas
  fun ref clear_deltas() => _deltas.clear()
  
  fun ref apply(r: Respond, cmd: Iterator[String])? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "INC" => add(r, _key(cmd)?, _value(cmd)?)
    | "DEC" => sub(r, _key(cmd)?, _value(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): I64? => cmd.next()?.i64()?
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try
      let delta = delta' as PNCounter box
      try _data(key)?.converge(delta)
      else _data(key) = PNCounter(_identity).>converge(delta)
      end
    end
  
  fun get(resp: Respond, key: String) =>
    resp.i64(try _data(key)?.value().i64() else 0 end)
  
  fun ref add(resp: Respond, key: String, value: I64) =>
    let delta =
      try _deltas(key)? else
        let d = PNCounter(_identity)
        _deltas(key) = d
        d
      end
    
    try _data(key)?.increment(value.u64(), delta)
    else _data(key) = PNCounter(_identity).>increment(value.u64(), delta)
    end
    
    resp.ok() // Consider issuing an error when "node-local value" overflows? (remember to update docs)
  
  fun ref sub(resp: Respond, key: String, value: I64) =>
    let delta =
      try _deltas(key)? else
        let d = PNCounter(_identity)
        _deltas(key) = d
        d
      end
    
    try _data(key)?.decrement(value.u64(), delta)
    else _data(key) = PNCounter(_identity).>decrement(value.u64(), delta)
    end
    
    resp.ok() // Consider issuing an error when "node-local value" underflows? (remember to update docs)
