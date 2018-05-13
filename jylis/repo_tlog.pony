use "collections"
use "crdt"
use "resp"

primitive RepoTLOGHelp is HelpRepo
  fun datatype(): String => "TLOG"
  fun commands(map: Map[String, String]) =>
    map("GET")    = "key [count]"
    map("INS")    = "key value timestamp"
    map("SIZE")   = "key"
    map("CUTOFF") = "key"
    map("TRIMAT") = "key timestamp"
    map("TRIM")   = "key count"
    map("CLR")    = "key"

class RepoTLOG
  let _data:  CKeyspace[String, TLog[String]]
  var _delta: CKeyspace[String, TLog[String]] = _delta.create(0)
  
  new create(identity: U64) => _data = _data.create(identity)
  
  fun ref delta_empty(): Bool => _delta.is_empty()
  fun ref flush_deltas(): Tokens => Tokens .> from(_delta = _delta.create(0))
  fun ref converge(tokens: TokensIterator)? =>
    _data.converge(_delta.create(0) .> from_tokens(tokens)?)
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GET"    => get(r, _key(cmd)?, _opt_count(cmd))
    | "INS"    => ins(r, _key(cmd)?, _value(cmd)?, _timestamp(cmd)?)
    | "SIZE"   => size(r, _key(cmd)?)
    | "CUTOFF" => cutoff(r, _key(cmd)?)
    | "TRIMAT" => trimat(r, _key(cmd)?, _timestamp(cmd)?)
    | "TRIM"   => trim(r, _key(cmd)?, _count(cmd)?)
    | "CLR"    => clr(r, _key(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _timestamp(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun tag _count(cmd: Iterator[String]): USize? => cmd.next()?.usize()?
  
  fun tag _opt_count(cmd: Iterator[String]): USize =>
    try cmd.next()?.usize()? else -1 end
  
  fun get(resp: Respond, key: String, count: USize): Bool =>
    try
      let log   = _data(key)?
      var total = log.size().min(count)
      resp.array_start(total)
      for (value, timestamp) in log.entries() do
        if 0 == (total = total - 1) then break end
        resp.array_start(2)
        resp.string(value)
        resp.u64(timestamp)
      end
    else
      resp.array_start(0)
    end
    false
  
  fun ref ins(resp: Respond, key: String, value: String, timestamp: U64): Bool =>
    _data.at(key).write(value, timestamp, _delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun size(resp: Respond, key: String): Bool =>
    resp.u64(try _data(key)?.size().u64() else 0 end)
    false
  
  fun cutoff(resp: Respond, key: String): Bool =>
    resp.u64(try _data(key)?.cutoff() else 0 end)
    false
  
  fun ref trimat(resp: Respond, key: String, timestamp: U64): Bool =>
    _data.at(key).raise_cutoff(timestamp, _delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref trim(resp: Respond, key: String, count: USize): Bool =>
    _data.at(key).trim(count, _delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
  
  fun ref clr(resp: Respond, key: String): Bool =>
    _data.at(key).clear(_delta.at(key))
    resp.ok()
    true // TODO: update CRDT library so we can return false if nothing changed
