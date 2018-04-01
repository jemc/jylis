use "collections"
use "resp"

actor HelpResponder
  be apply(resp: Respond, cmd: Array[String] val) =>
    let prefix = "BADCOMMAND (couldn't parse command)\n"
    resp.err(prefix + Help(cmd).clone().>rstrip())

primitive Help
  fun apply(cmd: Array[String] val): String =>
    RepoHelp(cmd.values())

trait val HelpLeaf
  fun datatype(): String
  fun commands(map: Map[String, String])
  
  fun apply(cmd: Iterator[String]): String =>
    let map = Map[String, String]
    commands(map)
    try
      let op   = cmd.next()?
      let args = map(op)?
      
      let buf = "This operation expects the arguments in the following form:".clone()
      (consume buf)
        .> push('\n')
        .> append(datatype())
        .> push(' ')
        .> append(op)
        .> push(' ')
        .> append(args)
    else
      let buf = "The following are valid operations for this data type:".clone()
      for (op, args) in map.pairs() do
        buf
          .> push('\n')
          .> append(datatype())
          .> push(' ')
          .> append(op)
          .> push(' ')
          .> append(args)
      end
      consume buf
    end
