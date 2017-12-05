use "time"
use "random"

actor Main
  new create(env: Env) =>
    try
      let auth    = env.root as AmbientAuth
      let name    = NameGenerator(Rand(Time.now()._2.u64()))()
      let log     = Log.create_fine(env.out)
      let addr    = Address("0.0.0.0", "9999", name)
      let cluster = Cluster(auth, log, addr, [])
      let server  = Server(auth, log, addr, cluster, "6379")
      env.out.print(Logo())
    end
