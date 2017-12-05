use "collections"
use "crdt"
use "resp"

class RepoGCOUNT
  let _identity: U64
  let _cluster: Cluster
  let _data: Map[String, GCounter] = _data.create()
  
  new create(identity': U64, cluster': Cluster) =>
    (_identity, _cluster) = (identity', cluster')
  
  fun ref apply(r: Respond, cmd: Iterator[String])? =>
    match cmd.next()?
    | "GET" => get(r, _key(cmd)?)
    | "ADD" => add(r, _key(cmd)?, _value(cmd)?)
    else error
    end
  
  fun tag _key(cmd: Iterator[String]): String? => cmd.next()?
  
  fun tag _value(cmd: Iterator[String]): U64? => cmd.next()?.u64()?
  
  fun get(resp: Respond, key: String) =>
    resp.u64(try _data(key)?.value() else 0 end)
  
  fun ref add(resp: Respond, key: String, value: U64) =>
    try _data(key)?.increment(value)
    else _data(key) = GCounter(_identity).>increment(value)
    end
    resp.ok() // Consider issuing an error when "node-local value" overflows? (remember to update docs)
