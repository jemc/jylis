use cli = "cli"
use "random"
use "time"

class Config
  let port: String
  let addr: Address
  let seed_addrs: Array[Address] = []
  
  new val create(env: Env) ? =>
    let spec = cli.CommandSpec.leaf("jylis", "", [
      cli.OptionSpec.string("port",
        "The port for accepting commands over RESP-protocol connections."
        where short' = 'p', default' = "6379")
      
      cli.OptionSpec.string("addr",
        "The host:port:name to be advertised to other clustering nodes."
        where short' = 'a', default' = "127.0.0.1:9999:")
      
      cli.OptionSpec.string("seed-addrs",
        "A space-separated list of the host:port:name for other known nodes."
        where short' = 's', default' = "")
    ], [
      cli.ArgSpec.string_seq("", "")
    ])?.>add_help()?
    
    let cmd =
      match cli.CommandParser(spec).parse(env.args, env.vars())
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
    
    var cluster_name = cmd.option("cluster-name").string()
    if cluster_name.size() == 0 then
      cluster_name = NameGenerator(Rand(Time.now()._2.u64()))()
    end
    
    port = cmd.option("port").string()
    
    var addr' = Address.from_string(cmd.option("addr").string())
    if addr'.name.size() == 0 then
      let name = NameGenerator(Rand(Time.now()._2.u64()))()
      addr' = Address(addr'.host, addr'.port, name)
    end
    addr = addr'
    
    for seed_str in cmd.option("seed-addrs").string().split(" ").values() do
      seed_addrs.push(Address.from_string(seed_str))
    end
