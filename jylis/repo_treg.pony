use "collections"
use "crdt"
use "resp"

primitive RepoTREGHelp is HelpRepo
  fun datatype(): String => "TREG"
  fun commands(map: Map[String, String]) =>
    map("GET") = "key"
    map("SET") = "key value timestamp"

class RepoTREG
  let _data:  CKeyspace[String, TRegString]
  var _delta: CKeyspace[String, TRegString] = _delta.create(0)
  
  new create(identity: U64) => _data = _data.create(identity)
  
  fun ref delta_empty(): Bool => _delta.is_empty()
  fun ref flush_deltas(): Tokens => Tokens .> from(_delta = _delta.create(0))
  fun ref converge(tokens: TokensIterator)? =>
    _data.converge(_delta.create(0) .> from_tokens(tokens)?)
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "SET" => set(r, _key(cmd)?, _value(cmd)?, _timestamp(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _timestamp(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun get(resp: Respond, key: String): Bool =>
    resp.array_start(2)
    try
      let reg = _data(key)?
      resp.string(reg.value())
      resp.u64(reg.timestamp())
    else
      resp.string("")
      resp.u64(0)
    end
    false
  
  fun ref set(resp: Respond, key: String, value: String, timestamp: U64): Bool =>
    _data.at(key).update(value, timestamp, _delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
