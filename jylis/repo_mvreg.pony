use "collections"
use "crdt"
use "resp"

primitive RepoMVREGHelp is HelpRepo
  fun datatype(): String => "MVREG"
  fun commands(map: Map[String, String]) =>
    map("GET") = "key"
    map("SET") = "key value"

class RepoMVREG
  let _data:  CKeyspace[String, MVReg[String]]
  var _delta: CKeyspace[String, MVReg[String]] = _delta.create(0)
  
  new create(identity: U64) => _data = _data.create(identity)
  
  fun ref delta_empty(): Bool => _delta.is_empty()
  fun ref flush_deltas(): Tokens => Tokens .> from(_delta = _delta.create(0))
  fun ref data_tokens(): Tokens => Tokens .> from(_data)
  fun ref history_tokens(): Tokens => let t = Tokens; _data.each_token_of_history(t); t
  fun ref converge(tokens: TokensIterator)? =>
    _data.converge(_delta.create(0) .> from_tokens(tokens)?)
  fun ref compare_history(tokens: TokensIterator): (Bool, Bool)? =>
    _data.compare_history_with_tokens(tokens)?
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "SET" => set(r, _key(cmd)?, _value(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): String? => cmd.next()?
  
  fun get(resp: Respond, key: String): Bool =>
    try
      let reg = _data(key)?
      resp.array_start(reg.size())
      for v in reg.values() do
        resp.string(v)
      end
    else
      resp.array_start(0)
    end
    false
  
  fun ref set(resp: Respond, key: String, value: String): Bool =>
    _data.at(key).update(value, _delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
