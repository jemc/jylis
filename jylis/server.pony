use "resp"

actor Server
  let _log: Log
  let _listen: _Listen
  let _repo: Repo = Repo
  
  new create(auth': AmbientAuth, log': Log, port': String) =>
    _log = log'
    
    let listen_notify = ServerListenNotify(this)
    _listen = _Listen(auth', consume listen_notify, "", port')
  
  be dispose() =>
    _listen.dispose()
  
  be _listen_failed() =>
    _log.err() and _log("listen failed")
    dispose()
  
  be _listen_ready() => None
    _log.info() and _log("listen ready")
  
  be apply(cmd: ElementsAny, resp: Respond) =>
    try
      match cmd(0)?
      | "TPUTS" =>
        _repo.tputs(resp, cmd(1)? as String, cmd(2)? as String, (cmd(3)? as String).u64()?)
      | "TGETS" =>
        _repo.tgets(resp, cmd(1)? as String)
      else error
      end
    else
      _log.err() and _log("couldn't parse command", cmd)
      resp.err("BADCOMMAND couldn't parse command")
    end
