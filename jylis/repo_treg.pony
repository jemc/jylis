use "collections"
use "crdt"
use "resp"

class RepoTREG[A: (Comparable[A] val & (String val | I64 val))]
  let _data:   Map[String, TReg[A]] = _data.create()
  let _deltas: Map[String, TReg[A]] = _deltas.create()
  
  new ref create() => None
  
  fun deltas(): Map[String, TReg[A]] box => _deltas
  fun ref clear_deltas() => _deltas.clear()
  
  fun ref apply(r: Respond, cmd: Iterator[String])? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "SET" =>
      // TODO: fix ponyc and use the _value function for the value argument.
      iftype A <: String then set(r, _key(cmd)?, cmd.next()?,        _timestamp(cmd)?)
      elseif A <: I64    then set(r, _key(cmd)?, cmd.next()?.i64()?, _timestamp(cmd)?)
      end
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  // fun tag _value(cmd: Iterator[String]): A? =>
  //   iftype A <: String val then cmd.next()?
  //   elseif A <: I64 val    then cmd.next()?.i64()?
  //   else error
  //   end
  
  fun tag _resp_value(resp: Respond, value: A) =>
    iftype A <: String val then resp.string(value)
    elseif A <: I64 val    then resp.i64(value)
    end
  
  fun tag _timestamp(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try
      let delta = delta' as TReg[A] box
      try _data(key)?.converge(delta)
      else _data(key) = TReg[A](delta.value(), delta.timestamp()) // TODO: delta.clone()
      end
    end
  
  fun get(resp: Respond, key: String) =>
    try
      let reg = _data(key)?
      resp.array_start(2)
      _resp_value(resp, reg.value())
      resp.u64(reg.timestamp())
    else
      resp.null()
    end
  
  fun ref set(resp: Respond, key: String, value: A, timestamp: U64) =>
    let delta =
      try _deltas(key)? else
        let d = TReg[A](value, timestamp)
        _deltas(key) = d
        d
      end
    
    try _data(key)?.update(value, timestamp, delta)
    else _data(key) = TReg[A](value, timestamp)
    end
    
    resp.ok()
