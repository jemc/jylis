use "resp"

actor Server
  let _log: Log
  let _cluster: Cluster
  let _listen: _Listen
  let _repo: Repo
  
  new create(auth': AmbientAuth, log': Log, cluster': Cluster, port': String) =>
    (_log, _cluster) = (log', cluster')
    
    let listen_notify = ServerListenNotify(this)
    _listen = _Listen(auth', consume listen_notify, "", port')
    
    _repo = Repo(_cluster)
  
  be dispose() =>
    _listen.dispose()
  
  be _listen_failed() =>
    _log.err() and _log("listen failed")
    dispose()
  
  be _listen_ready() => None
    _log.info() and _log("listen ready")
  
  be apply(resp: Respond, cmd: Array[String] val) =>
    try
      _repo(resp, cmd.values())?
    else
      _log.err() and _log("couldn't parse command", cmd)
      resp.err("BADCOMMAND couldn't parse command")
    end
