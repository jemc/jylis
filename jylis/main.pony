actor Main
  new create(env: Env) =>
    try
      env.out.print(Logo())
      let auth     = env.root as AmbientAuth
      let system   = System(ConfigFromCLI(env, env.out)?)
      let database = Database(system)
      let disk     = DiskSetup(system) .> replay(database)
      let server   = Server(auth, system, database)
      let cluster  = Cluster(auth, system, database, disk)
      system.dispose.setup(database, disk, server, cluster)
    end
