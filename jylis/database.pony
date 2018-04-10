use "collections"
use "promises"
use "resp"

class val Database
  let _config: Config
  let _map: Map[String, RepoManagerAny] = _map.create()
  
  new val create(config': Config) =>
    _config = config'
    
    let identity = _config.addr.hash()
    // TODO: allow users to create their own keyspaces/repos with custom types,
    // noting that allowing this requires a CRDT data structure for this map
    // of repos, with some way of resolving conflicts that doesn't break things
    // for the user who has already started storing data in the repo?
    _map("TREG")    = RepoManager[RepoTREG,    RepoTREGHelp]   ("TREG",    identity)
    _map("TLOG")    = RepoManager[RepoTLOG,    RepoTLOGHelp]   ("TLOG",    identity)
    _map("GCOUNT")  = RepoManager[RepoGCOUNT,  RepoGCOUNTHelp] ("GCOUNT",  identity)
    _map("PNCOUNT") = RepoManager[RepoPNCOUNT, RepoPNCOUNTHelp]("PNCOUNT", identity)
    _map("UJSON")   = RepoManager[RepoUJSON,   RepoUJSONHelp]  ("UJSON",   identity)
  
  fun apply(resp: Respond, cmd: Array[String] val) =>
    try
      _map(cmd(0)?)?(resp, cmd)
    else
      HelpRespond(resp,
        """
        The first word of each command must be a data type.
        The following are valid data types (case sensitive):
          TREG    - Timestamped Register (Latest Write Wins)
          TLOG    - Timestamped Log (Retain Latest Entries)
          GCOUNT  - Grow-Only Counter
          PNCOUNT - Positive/Negative Counter
          UJSON   - Unordered JSON (Nested Observed-Remove Maps and Sets)
        """)
    end
  
  fun flush_deltas(fn: _SendDeltasFn) =>
    let out: Array[(String, Array[(String, Any box)] box)] = []
    var deltas_size: USize = 0
    
    for (name, repo) in _map.pairs() do
      repo.flush_deltas(fn)
    end
  
  fun converge_deltas(deltas: (String, Array[(String, Any box)] val)) =>
    try _map(deltas._1)?.converge_deltas(deltas._2) end
  
  fun clean_shutdown(): Promise[None] =>
    """
    Return a promise that is fulfilled when all RepoManagers in the _map
    have finished executing their owne clean_shutdown behaviour.
    """
    _config.log.info() and _config.log("database shutting down")
    let promises = Array[Promise[None]]
    for r in _map.values() do
      let promise = Promise[None]
      promises.push(promise)
      r.clean_shutdown(promise)
    end
    Promises[None].join(promises.values()).next[None]({(_) => _ })
