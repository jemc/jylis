actor Server
  let _system: System
  let _database: Database
  let _listen: _Listen
  
  new create(auth': AmbientAuth, system': System, database': Database) =>
    (_system, _database) = (system', database')
    
    // TODO: Allow a configurable listen IP / interface instead of "".
    let listen_notify = ServerListenNotify(this, _database)
    _listen = _Listen(auth', consume listen_notify, "", _system.config.port)
  
  be dispose() =>
    _system.log.info() and _system.log.i("server listener shutting down")
    _listen.dispose()
    // TODO: shut down client connections, ideally waiting until
    // they no longer have any pending commands.
  
  be _listen_failed() =>
    _system.log.err() and _system.log.e(
      "server listener failed to listen on port " + _system.config.port
    )
    dispose()
  
  be _listen_ready() => None
    _system.log.info() and _system.log.i(
      "server listener ready on port " + _system.config.port
    )
