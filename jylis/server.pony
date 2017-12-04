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
  
  be apply(cmd: Array[String] val, resp: Respond) =>
    try
      match cmd(0)?
      | "TPUTS" =>
        _repo.tputs(resp, cmd(1)?, cmd(2)?, cmd(3)?.u64()?)
      | "TGETS" =>
        _repo.tgets(resp, cmd(1)?)
      else error
      end
    else
      _log.err() and _log("couldn't parse command", cmd)
      resp.err("BADCOMMAND couldn't parse command")
    end
