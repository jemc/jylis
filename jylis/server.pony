use "resp"

actor Server
  let _log: Log
  let _addr: Address
  let _listen: _Listen
  let _repo: Repo
  
  new create(
    auth': AmbientAuth,
    log': Log,
    addr': Address,
    port': String)
  =>
    (_log, _addr) = (log', addr')
    
    let listen_notify = ServerListenNotify(this)
    _listen = _Listen(auth', consume listen_notify, "", port')
    
    _repo = Repo(_addr.hash())
  
  be dispose() =>
    _listen.dispose()
  
  be _listen_failed() =>
    _log.err() and _log("listen failed")
    dispose()
  
  be _listen_ready() => None
    _log.info() and _log("listen ready")
  
  be apply(resp: Respond, cmd: Array[String] val) =>
    _repo(resp, cmd)
  
  be flush_deltas(cluster: Cluster, serial: _Serialise) =>
    _repo.flush_deltas(cluster, serial)
  
  be converge_deltas(deltas: (String, Array[(String, Any box)] val)) =>
    _repo.converge_deltas(deltas)
