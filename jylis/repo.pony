use "collections"
use "resp"

class val Repo
  let _map: Map[String, RepoManagerAny] = _map.create()
  
  new val create(identity': U64) =>
    // TODO: allow users to create their own keyspaces/repos with custom types,
    // noting that allowing this requires a CRDT data structure for this map
    // of repos, with some way of resolving conflicts that doesn't break things
    // for the user who has already started storing data in the repo?
    _map("TREG")    = RepoManager[RepoTREG,    RepoTREGHelp]   (identity')
    _map("GCOUNT")  = RepoManager[RepoGCOUNT,  RepoGCOUNTHelp] (identity')
    _map("PNCOUNT") = RepoManager[RepoPNCOUNT, RepoPNCOUNTHelp](identity')
    _map("UJSON")   = RepoManager[RepoUJSON,   RepoUJSONHelp]  (identity')
  
  fun apply(resp: Respond, cmd: Array[String] val) =>
    try
      _map(cmd(0)?)?(resp, cmd)
    else
      HelpRespond(resp,
        """
        The first word of each command must be a data type.
        The following are valid data types (case sensitive):
          TREG    - Timestamped Register (Latest Write Wins)
          GCOUNT  - Grow-Only Counter
          PNCOUNT - Positive/Negative Counter
          UJSON   - Unordered JSON (Nested Observed-Remove Maps and Sets)
        """)
    end
  
  fun flush_deltas(cluster: Cluster, serial: _Serialise) =>
    let out: Array[(String, Array[(String, Any box)] box)] = []
    var deltas_size: USize = 0
    
    for (name, repo) in _map.pairs() do
      repo.flush_deltas(name, cluster, serial)
    end
  
  fun converge_deltas(deltas: (String, Array[(String, Any box)] val)) =>
    try _map(deltas._1)?.converge_deltas(deltas._2) end
