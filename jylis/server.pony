use "resp"

actor Server
  let _log: Log
  let _listen: _Listen
  
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
    _log.fine() and _log(cmd)
    resp.ok()
