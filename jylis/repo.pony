use crdt = "crdt"
use "resp"
use "collections"

interface RepoAny
  fun ref apply(r: Respond, cmd: Iterator[String])?
  fun ref deltas_size(): USize
  fun ref flush_deltas(): Array[(String, Any box)] box
  fun ref converge(key: String, delta': Any box)

class Repo
  let _map: Map[String, RepoAny] = _map.create()
  
  new create(identity': U64) =>
    // TODO: allow users to create their own keyspaces/repos with custom types,
    // noting that allowing this requires a CRDT data structure for this map
    // of repos, with some way of resolving conflicts that doesn't break things
    // for the user who has already started storing data in the repo?
    _map("TREG")    = RepoTREG
    _map("GCOUNT")  = RepoGCOUNT(identity')
    _map("PNCOUNT") = RepoPNCOUNT(identity')
  
  fun ref apply(resp: Respond, cmd: Iterator[String])? =>
    _map(cmd.next()?)?(resp, cmd)?
  
  fun ref flush_deltas(cluster: Cluster, serial: _Serialise) =>
    let out: Array[(String, Array[(String, Any box)] box)] = []
    var deltas_size: USize = 0
    
    for (t, repo) in _map.pairs() do
      if repo.deltas_size() > 0 then
        out.push((t, repo.flush_deltas()))
      end
    end
    
    if out.size() > 0 then
      cluster.broadcast_deltas(serial, out)
    end
  
  fun ref converge_deltas(
    deltas: Array[(String, Array[(String, Any box)] box)] val)
  =>
    for (t, list) in deltas.values() do
      try
        let repo = _map(t)?
        for (k, d) in list.values() do repo.converge(k, d) end
        // TODO: when keyspaces/repos are dynamic, deal with else case here.
      end
    end
