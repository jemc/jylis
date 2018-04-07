actor Server
  let _config: Config
  let _database: Database
  let _listen: _Listen
  
  new create(
    auth': AmbientAuth,
    config': Config,
    database': Database)
  =>
    (_config, _database) = (config', database')
    
    let listen_notify = ServerListenNotify(this, _database)
    _listen = _Listen(auth', consume listen_notify, "", _config.port)
  
  be dispose() =>
    _config.log.info() and _config.log("server listener shutting down")
    _listen.dispose()
    // TODO: shut down client connections, ideally waiting until
    // they no longer have any pending commands.
  
  be _listen_failed() =>
    _config.log.err() and _config.log("server listener failed to listen")
    dispose()
  
  be _listen_ready() => None
    _config.log.info() and _config.log("server listener ready")
