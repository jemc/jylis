use "time"
use "resp"

interface RepoAny
  new ref create(identity': U64)
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool?
  fun ref deltas_size(): USize
  fun ref flush_deltas(): Array[(String, Any box)] box
  fun ref converge(key: String, delta': Any box)

interface tag RepoManagerAny
  be apply(resp: Respond, cmd: Array[String] val)
  be flush_deltas(fn: _SendDeltasFn)
  be converge_deltas(deltas: Array[(String, Any box)] val)

actor RepoManager[R: RepoAny ref, H: HelpLeaf val]
  let _name: String
  let _repo: R
  var _deltas_fn: (_SendDeltasFn | None) = None
  var _last_proactive: U64 = 0
  
  new create(name': String, identity': U64) =>
    (_name, _repo) = (name', R(identity'))
  
  be apply(resp: Respond, cmd: Array[String] val) =>
    try
      let iter = cmd.values()
      iter.next()? // discard first word; it was already read to route us here
      let changed = _repo(resp, iter)?
      if changed then _maybe_proactive_flush() end
    else
      let iter = cmd.values()
      try iter.next()? end // try to discard the first word, or don't...
      HelpRespond(resp, H(iter))
    end
  
  fun ref _maybe_proactive_flush() =>
    """
    When we know there has been a recent change to the data, we can choose to
    proactively flush our deltas to the other replicas, for more immediate
    propagation of changes. We use a simple heuristic that allows us to do
    proactive propagation at most once every 500 milliseconds.
    
    We can only do this if we've already received and stored a _SendDeltasFn.
    """
    try
      let fn = _deltas_fn as _SendDeltasFn
      let now = Time.millis()
      if (now - 500) >= _last_proactive then
        fn((_name, _repo.flush_deltas()))
        _last_proactive = now
      end
    end
  
  be flush_deltas(fn: _SendDeltasFn) =>
    _deltas_fn = fn
    if _repo.deltas_size() > 0 then
      fn((_name, _repo.flush_deltas()))
    end
  
  be converge_deltas(deltas: Array[(String, Any box)] val) =>
    for (k, d) in deltas.values() do _repo.converge(k, d) end
