actor Main
  new create(env: Env) =>
    try
      env.out.print(Logo())
      let auth     = env.root as AmbientAuth
      let system   = System(ConfigFromCLI(env, env.err)?)
      let database = Database(system)
      let disk     = DiskSetup(system, database)
      let server   = Server(auth, system, database)
      let cluster  = Cluster(auth, system, database)
      system.dispose.setup(database, server, cluster)
    end
