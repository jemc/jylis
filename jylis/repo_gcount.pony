use "collections"
use "crdt"
use "resp"

primitive RepoGCOUNTHelp is HelpRepo
  fun datatype(): String => "GCOUNT"
  fun commands(map: Map[String, String]) =>
    map("GET") = "key"
    map("INC") = "key value"

class RepoGCOUNT
  let _data:  CKeyspace[String, GCounter]
  var _delta: CKeyspace[String, GCounter] = _delta.create(0)
  
  new create(identity: U64) => _data = _data.create(identity)
  
  fun ref delta_empty(): Bool => _delta.is_empty()
  fun ref flush_deltas(): Tokens => Tokens .> from(_delta = _delta.create(0))
  fun ref converge(tokens: TokensIterator)? =>
    _data.converge(_delta.create(0) .> from_tokens(tokens)?)
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "INC" => inc(r, _key(cmd)?, _value(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun get(resp: Respond, key: String): Bool =>
    resp.u64(try _data(key)?.value() else 0 end)
    false
  
  fun ref inc(resp: Respond, key: String, value: U64): Bool =>
    _data.at(key).increment(value, _delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
