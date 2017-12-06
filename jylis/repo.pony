use crdt = "crdt"
use "resp"

class Repo
  let _tregs:   RepoTREG[String]
  let _tregi:   RepoTREG[I64]
  let _gcount:  RepoGCOUNT
  let _pncount: RepoPNCOUNT
  
  new create(identity': U64) =>
    _tregs   = RepoTREG[String]
    _tregi   = RepoTREG[I64]
    _gcount  = RepoGCOUNT(identity')
    _pncount = RepoPNCOUNT(identity')
  
  fun ref apply(resp: Respond, cmd: Iterator[String])? =>
    match cmd.next()?
    | "TREGS"   => _tregs(resp, cmd)?
    | "TREGI"   => _tregi(resp, cmd)?
    | "GCOUNT"  => _gcount(resp, cmd)?
    | "PNCOUNT" => _pncount(resp, cmd)?
    else error
    end
    if cmd.has_next() then error end
  
  fun ref flush_deltas(cluster: Cluster, serial: _Serialise) =>
    let out: Array[(String, Array[(String, Any box)] box)] = []
    var deltas_size: USize = 0
    
    deltas_size = _tregs.deltas().size()
    if deltas_size > 0 then
      let out' = Array[(String, Any box)](deltas_size)
      for (k, d) in _tregs.deltas().pairs() do out'.push((k, d)) end
      _tregs.clear_deltas()
      out.push(("TREGS", out'))
    end
    
    deltas_size = _tregi.deltas().size()
    if deltas_size > 0 then
      let out' = Array[(String, Any box)](deltas_size)
      for (k, d) in _tregi.deltas().pairs() do out'.push((k, d)) end
      _tregi.clear_deltas()
      out.push(("TREGI", out'))
    end
    
    deltas_size = _gcount.deltas().size()
    if deltas_size > 0 then
      let out' = Array[(String, Any box)](deltas_size)
      for (k, d) in _gcount.deltas().pairs() do out'.push((k, d)) end
      _gcount.clear_deltas()
      out.push(("GCOUNT", out'))
    end
    
    deltas_size = _pncount.deltas().size()
    if deltas_size > 0 then
      let out' = Array[(String, Any box)](deltas_size)
      for (k, d) in _pncount.deltas().pairs() do out'.push((k, d)) end
      _pncount.clear_deltas()
      out.push(("PNCOUNT", out'))
    end
    
    if out.size() > 0 then
      cluster.broadcast_deltas(serial, out)
    end
  
  fun ref converge_deltas(
    deltas: Array[(String, Array[(String, Any box)] box)] val)
  =>
    for (t, list) in deltas.values() do
      match t
      | "TREGS"   => for (k, d) in list.values() do _tregs.converge(k, d) end
      | "TREGI"   => for (k, d) in list.values() do _tregi.converge(k, d) end
      | "GCOUNT"  => for (k, d) in list.values() do _gcount.converge(k, d) end
      | "PNCOUNT" => for (k, d) in list.values() do _pncount.converge(k, d) end
      end
    end
