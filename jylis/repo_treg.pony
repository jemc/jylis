use "collections"
use "crdt"
use "resp"

primitive RepoTREGHelp is HelpLeaf
  fun datatype(): String => "TREG"
  fun commands(map: Map[String, String]) =>
    map("GET") = "key"
    map("SET") = "key value timestamp"

class RepoTREG
  let _data:   Map[String, TReg[String]] = _data.create()
  let _deltas: Map[String, TReg[String]] = _deltas.create()
  
  new ref create(identity': U64) => None
  
  fun ref deltas_size(): USize => _deltas.size()
  fun ref flush_deltas(): Array[(String, Any box)] box =>
    let out = Array[(String, Any box)](_deltas.size())
    for (k, d) in _deltas.pairs() do out.push((k, d)) end
    _deltas.clear()
    out
  
  fun ref apply(r: Respond, cmd: Iterator[String])? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "SET" => set(r, _key(cmd)?, cmd.next()?, _timestamp(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _timestamp(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun ref converge(key: String, delta': Any box) => // TODO: more strict
    try
      let delta = delta' as TReg[String] box
      try _data(key)?.converge(delta)
      else _data(key) = TReg[String](delta.value(), delta.timestamp()) // TODO: delta.clone()
      end
    end
  
  fun get(resp: Respond, key: String) =>
    try
      let reg = _data(key)?
      resp.array_start(2)
      resp.string(reg.value())
      resp.u64(reg.timestamp())
    else
      resp.null()
    end
  
  fun ref set(resp: Respond, key: String, value: String, timestamp: U64) =>
    let delta =
      try _deltas(key)? else
        let d = TReg[String](value, timestamp)
        _deltas(key) = d
        d
      end
    
    try _data(key)?.update(value, timestamp, delta)
    else _data(key) = TReg[String](value, timestamp)
    end
    
    resp.ok()
