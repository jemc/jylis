use "promises"
use crdt = "crdt"
use "resp"

class val System
  let config:  Config
  let dispose: SystemDispose
  let repo:    SystemRepoManager
  let log:     Log
  
  new val create(config': Config) =>
    config  = config'
    dispose = SystemDispose
    repo    = SystemRepoManager(config)
    log     = config.log .> set_sys(repo)
    
    // Set up disk persistence (if applicable) or shut down if it failed.
    try config.disk.setup(log)? else dispose() end

actor SystemDispose
  var _dispose: (Dispose | None) = None
  var _dispose_when_ready: Bool = false
  
  be setup(database: Database, server: Server, cluster: Cluster) =>
    _dispose = Dispose(database, server, cluster) .> on_signal()
    if _dispose_when_ready then apply() end
  
  be apply() =>
    try (_dispose as Dispose).dispose() else _dispose_when_ready = true end

actor SystemRepoManager is RepoManagerAny
  let _config: Config
  let _core: RepoManagerCore[RepoSYSTEM, RepoSYSTEMHelp]
  
  new create(config': Config) =>
    _config = config'
    _core   = _core.create("SYSTEM", _config.addr.hash64())
  
  be apply(resp: Respond, cmd: Array[String] val) =>
    _core(resp, cmd)
  
  be flush_deltas(fn: _SendDeltasFn) =>
    _core.flush_deltas(fn)
  
  be converge_deltas(deltas: crdt.TokensIterator iso) =>
    _core.converge_deltas(consume deltas)
  
  be clean_shutdown(promise: Promise[None]) =>
    _core.clean_shutdown(promise)
  
  ///
  // System private methods, meant for use only within the jylis server.
  // Generally, the purpose is to fill data that is read-only to the user.
  
  be log(string': String) =>
    let string: String = _config.addr.string().>push(' ').>append(string')
    _core.repo()._inslog(string)
    _core.repo()._trimlog(_config.system_log_trim)
