use "resp"

class Repo
  let _tregs: RepoTREG[String]
  let _tregi: RepoTREG[I64]
  
  new create(cluster: Cluster) =>
    _tregs = RepoTREG[String](cluster)
    _tregi = RepoTREG[I64](cluster)
  
  fun ref apply(resp: Respond, cmd: Iterator[String])? =>
    match cmd.next()?
    | "TREGS" => _tregs(resp, cmd)?
    | "TREGI" => _tregi(resp, cmd)?
    else error
    end
    if cmd.has_next() then error end
