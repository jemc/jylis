use logger = "logger"
use "resp"

actor Server
  let _log: logger.Logger[String]
  let _listen: _Listen
  
  new create(auth': AmbientAuth, log': logger.Logger[String], port': String) =>
    _log = log'
    
    let listen_notify = ServerListenNotify(this)
    _listen = _Listen(auth', consume listen_notify, "", port')
  
  be dispose() =>
    _listen.dispose()
  
  be _listen_failed() =>
    _log(logger.Error) and _log.log("listen failed")
    dispose()
  
  be _listen_ready() => None
    _log(logger.Info) and _log.log("listen ready")
  
  be apply(cmd: ElementsAny, resp: Respond) =>
    _log(logger.Fine) and _log.log(cmd.string())
    resp.ok()
