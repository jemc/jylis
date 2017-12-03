
actor Main
  new create(env: Env) =>
    try
      let log = Log.create_fine(env.out)
      Server(env.root as AmbientAuth, log, "6379")
      env.out.print(Logo())
    end
