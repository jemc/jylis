actor Server
  let _log: Log
  let _addr: Address
  let _database: Database
  let _listen: _Listen
  
  new create(
    auth': AmbientAuth,
    log': Log,
    addr': Address,
    port': String,
    database': Database)
  =>
    (_log, _addr, _database) = (log', addr', database')
    
    let listen_notify = ServerListenNotify(this, _database)
    _listen = _Listen(auth', consume listen_notify, "", port')
  
  be dispose() =>
    _listen.dispose()
  
  be _listen_failed() =>
    _log.err() and _log("listen failed")
    dispose()
  
  be _listen_ready() => None
    _log.info() and _log("listen ready")
