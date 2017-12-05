use "collections"
use "crdt"
use "resp"

class Repo
  let _tregs: RepoTREG[String]
  let _tregi: RepoTREG[I64]
  
  new create(cluster: Cluster) =>
    _tregs = RepoTREG[String](cluster)
    _tregi = RepoTREG[I64](cluster)
  
  fun ref apply(resp: Respond, cmd: Iterator[String])? =>
    match cmd.next()?
    | "TREGS" => _tregs(resp, cmd)?
    | "TREGI" => _tregi(resp, cmd)?
    else error
    end
    if cmd.has_next() then error end

class RepoTREG[A: (Comparable[A] val & (String val | I64 val))]
  let _cluster: Cluster
  let _data: Map[String, LWWReg[A]] = _data.create()
  
  new create(cluster': Cluster) => _cluster = cluster'
  
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
    try _data(key)?.update(value, timestamp)
    else _data(key) = LWWReg[A](value, timestamp)
    end
    resp.ok()
