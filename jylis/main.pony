use "logger"

actor Main
  new create(env: Env) =>
    try
      let log = StringLogger(Fine, env.out)
      Server(env.root as AmbientAuth, log, "6379")
      env.out.print(Logo())
    end
