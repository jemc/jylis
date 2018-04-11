use "collections"
use "resp"

primitive HelpRespond
  fun apply(resp: Respond, help: String) =>
    let prefix = "BADCOMMAND (could not parse command)\n"
    resp.err(prefix + help.clone().>rstrip())

interface val HelpLeaf
  new val create()
  fun apply(cmd: Iterator[String]): String

trait val HelpRepo is HelpLeaf
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
