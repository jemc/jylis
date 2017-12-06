actor Main
  new create(env: Env) =>
    try
      let auth    = env.root as AmbientAuth
      let log     = Log.create_fine(env.out)
      let config  = Config(env)?
      let server  = Server(auth, log, config.addr, config.port)
      let cluster = Cluster(auth, log, config.addr, config.seed_addrs, server)
      // TODO: interrupt handler to broadcast deltas before graceful shutdown.
      env.out.print(Logo())
      env.out.print("advertises cluster address: " + config.addr.string())
      env.out.print("serves commands on port:    " + config.port)
    end
