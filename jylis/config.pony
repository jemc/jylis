use cli = "cli"
use "random"
use "time"

class val Config
  var port:            String         = "6379"
  var addr:            Address        = Address.from_string("127.0.0.1:9999:")
  var seed_addrs:      Array[Address] = []
  var heartbeat_time:  F64            = 10
  var system_log_trim: USize          = 200
  var log:             Log            = Log.create_none()
  
  fun ref normalize() =>
    // Force a random name if the addr.name is empty.
    if addr.name.size() == 0 then
      let name = NameGenerator(Rand(Time.now()._2.u64()))()
      addr = Address(addr.host, addr.port, name)
    end

primitive ConfigFromCLI
  fun _parse(env: Env): cli.Command? =>
    let spec = cli.CommandSpec.leaf("jylis", "", [
      cli.OptionSpec.string("addr",
        "The host:port:name to be advertised to other clustering nodes."
        where short' = 'a', default' = "127.0.0.1:9999:")
      
      cli.OptionSpec.string("port",
        "The port for accepting commands over RESP-protocol connections."
        where short' = 'p', default' = "6379")
      
      cli.OptionSpec.string("seed-addrs",
        "A space-separated list of the host:port:name for other known nodes."
        where short' = 's', default' = "")
      
      cli.OptionSpec.f64("heartbeat-time",
        "The number of seconds between heartbeats in the clustering protocol."
        where short' = 'T', default' = 10)
      
      cli.OptionSpec.u64("system-log-trim",
        "The number of entries to retain in the distributed `SYSTEM GETLOG`."
        where short' = 'T', default' = 200)
      
      cli.OptionSpec.string("log-level",
        "Maximum level of detail for logging (error, warn, info, or debug)."
        where short' = 'L', default' = "info")
    ], [
      cli.ArgSpec.string_seq("", "")
    ])?.>add_help()?
    
    match cli.CommandParser(spec).parse(env.args, env.vars)
    | let c: cli.Command => c
    | let c: cli.CommandHelp =>
      c.print_help(env.out)
      env.exitcode(0)
      error
    | let err: cli.SyntaxError =>
      env.out.print(err.string())
      env.exitcode(1)
      error
    end
  
  fun apply(env: Env, log_out: OutStream): Config? =>
    let cmd    = _parse(env)?
    let config = Config
    
    config.port = cmd.option("port").string()
    
    var addr = Address.from_string(cmd.option("addr").string())
    if addr.name.size() == 0 then
      let name = NameGenerator(Rand(Time.now()._2.u64()))()
      addr = Address(addr.host, addr.port, name)
    end
    config.addr = addr
    
    var seed_addrs: Array[Address] iso = []
    for seed_str in cmd.option("seed-addrs").string().split(" ").values() do
      seed_addrs.push(Address.from_string(seed_str))
    end
    config.seed_addrs = consume seed_addrs
    
    config.heartbeat_time = cmd.option("heartbeat-time").f64()
    
    config.system_log_trim = cmd.option("system-log-trim").u64().usize()
    
    config.log =
      match cmd.option("log-level").string()
      | "error" => Log.create_err(log_out)
      | "warn"  => Log.create_warn(log_out)
      | "info"  => Log.create_info(log_out)
      | "debug" => Log.create_debug(log_out)
      else
        env.out.print("Unknown log-level: " + cmd.option("log-level").string())
        error
      end
    
    config.normalize()
    config
