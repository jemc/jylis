use "collections"
use "promises"
use crdt = "crdt"
use "resp"

class val Database
  let _system: System
  let _map: Map[String, RepoManagerAny] = _map.create()
  
  new val create(system': System) =>
    _system = system'
    
    let identity = _system.config.addr.hash64()
    // TODO: allow users to create their own keyspaces/repos with custom types,
    // noting that allowing this requires a CRDT data structure for this map
    // of repos, with some way of resolving conflicts that doesn't break things
    // for the user who has already started storing data in the repo?
    _map("TREG")    = RepoManager[RepoTREG,    RepoTREGHelp]   ("TREG",    identity)
    _map("TLOG")    = RepoManager[RepoTLOG,    RepoTLOGHelp]   ("TLOG",    identity)
    _map("GCOUNT")  = RepoManager[RepoGCOUNT,  RepoGCOUNTHelp] ("GCOUNT",  identity)
    _map("PNCOUNT") = RepoManager[RepoPNCOUNT, RepoPNCOUNTHelp]("PNCOUNT", identity)
    _map("MVREG")   = RepoManager[RepoMVREG,   RepoMVREGHelp]  ("MVREG",   identity)
    _map("UJSON")   = RepoManager[RepoUJSON,   RepoUJSONHelp]  ("UJSON",   identity)
    _map("SYSTEM")  = _system.repo
  
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
          MVREG   - Multi-Value Register (Observed-Remove Set)
          UJSON   - Unordered JSON (Nested Observed-Remove Maps and Sets)
          SYSTEM  - (miscellaneous system-level operations)
        """)
    end
  
  fun forget_all() =>
    _system.log.info() and _system.log.i("database forgetting all data")
    for repo in _map.values() do
      repo.forget_all()
    end
  
  fun flush_deltas(fn: _NameTokensFn) =>
    for repo in _map.values() do
      repo.flush_deltas(fn)
    end
  
  fun converge_deltas(name: String, deltas: crdt.TokensIterator iso) =>
    try _map(name)?.converge_deltas(consume deltas) end
  
  fun send_all_history(send_fn: _NameTokensFn) =>
    for repo in _map.values() do
      repo.send_history(send_fn)
    end
  
  fun send_data(name: String, send_fn: _NameTokensFn) =>
    try _map(name)?.send_data(send_fn) end
  
  fun compare_history(
    name: String,
    history: crdt.TokensIterator iso,
    send_fn: _NameTokensFn,
    need_fn: _NameFn)
  =>
    try _map(name)?.compare_history(consume history, send_fn, need_fn) end
  
  fun clean_shutdown(): Promise[None] =>
    """
    Return a promise that is fulfilled when all RepoManagers in the _map
    have finished executing their own clean_shutdown behaviour.
    """
    _system.log.info() and _system.log.i("database shutting down")
    let promises = Array[Promise[None]]
    for r in _map.values() do
      let promise = Promise[None]
      promises.push(promise)
      r.clean_shutdown(promise)
    end
    Promises[None].join(promises.values()).next[None]({(_) => _ })
