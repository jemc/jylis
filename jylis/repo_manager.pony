use "resp"

interface RepoAny
  new ref create(identity': U64)
  fun ref apply(r: Respond, cmd: Iterator[String])?
  fun ref deltas_size(): USize
  fun ref flush_deltas(): Array[(String, Any box)] box
  fun ref converge(key: String, delta': Any box)

interface tag RepoManagerAny
  be apply(resp: Respond, cmd: Array[String] val)
  be flush_deltas(name: String, cluster: Cluster, serial: _Serialise)
  be converge_deltas(deltas: Array[(String, Any box)] val)

actor RepoManager[R: RepoAny ref, H: HelpLeaf val]
  let _repo: R
  
  new create(identity': U64) => _repo = R(identity')
  
  be apply(resp: Respond, cmd: Array[String] val) =>
    try
      let iter = cmd.values()
      iter.next()? // discard first word; it was already read to route us here
      _repo(resp, iter)?
    else
      let iter = cmd.values()
      try iter.next()? end // try to discard the first word, or don't...
      HelpRespond(resp, H(iter))
    end
  
  be flush_deltas(name: String, cluster: Cluster, serial: _Serialise) =>
    if _repo.deltas_size() > 0 then
      cluster.broadcast_deltas(serial, (name, _repo.flush_deltas()))
    end
  
  be converge_deltas(deltas: Array[(String, Any box)] val) =>
    for (k, d) in deltas.values() do _repo.converge(k, d) end
