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
    _log.info() and _log("server listener shutting down")
    _listen.dispose()
    // TODO: shut down client connections, ideally waiting until
    // they no longer have any pending commands.
  
  be _listen_failed() =>
    _log.err() and _log("server listener failed to listen")
    dispose()
  
  be _listen_ready() => None
    _log.info() and _log("server listener ready")
