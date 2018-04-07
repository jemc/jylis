actor Main
  new create(env: Env) =>
    try
      let auth     = env.root as AmbientAuth
      let log      = Log.create_fine(env.out)
      let config   = ConfigFromCLI(env)?
      let database = Database(config)
      let server   = Server(auth, config, database)
      let cluster  = Cluster(auth, config, database)
      Dispose(database, server, cluster).on_signal()
      
      env.out.print(Logo())
      env.out.print("advertises cluster address: " + config.addr.string())
      env.out.print("serves commands on port:    " + config.port)
    end
