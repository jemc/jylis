use "collections"
use "crdt"
use "resp"

class Repo
  let _data_tputs: Map[String, LWWReg[String]] = _data_tputs.create()
  
  fun ref tputs(resp: Respond, key: String, value: String, timestamp: U64) =>
    try _data_tputs(key)?.update(value, timestamp)
    else _data_tputs(key) = LWWReg[String](value, timestamp)
    end
    resp.ok()
  
  fun ref tgets(resp: Respond, key: String) =>
    try
      let reg = _data_tputs(key)?
      resp.array_start(2)
      resp.string(reg.value())
      resp.u64(reg.timestamp())
    else
      resp.null()
    end
