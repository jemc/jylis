use "time"
use "promises"
use crdt = "crdt"
use "resp"

interface RepoAny
  new ref create(identity': U64)
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool?
  fun ref delta_empty(): Bool
  fun ref flush_deltas(): crdt.Tokens
  fun ref converge(tokens: crdt.TokensIterator)?

interface tag RepoManagerAny
  be apply(resp: Respond, cmd: Array[String] val)
  be flush_deltas(fn: _NameTokensFn)
  be converge_deltas(deltas: crdt.TokensIterator iso)
  be clean_shutdown(promise: Promise[None])

actor RepoManager[R: RepoAny ref, H: HelpLeaf val] is RepoManagerAny
  let _core: RepoManagerCore[R, H]
  
  new create(name': String, identity': U64) =>
    _core = _core.create(name', identity')
  
  be apply(resp: Respond, cmd: Array[String] val) =>
    _core(resp, cmd)
  
  be flush_deltas(fn: _NameTokensFn) =>
    _core.flush_deltas(fn)
  
  be converge_deltas(deltas: crdt.TokensIterator iso) =>
    _core.converge_deltas(consume deltas)
  
  be clean_shutdown(promise: Promise[None]) =>
    _core.clean_shutdown(promise)

class RepoManagerCore[R: RepoAny ref, H: HelpLeaf val]
  let _name: String
  let _repo: R
  var _deltas_fn: (_NameTokensFn | None) = None
  var _last_proactive: U64 = 0
  var _shutdown: Bool = false
  
  new create(name': String, identity': U64) =>
    (_name, _repo) = (name', R(identity'))
  
  fun name(): String => _name
  fun repo(): this->R => _repo
  
  fun ref apply(resp: Respond, cmd: Array[String] val) =>
    if _shutdown then
      resp.err("SHUTDOWN (server is shutting down, rejecting all requests)")
      // TODO: also terminate the client's TCP connection,
      // so that busy clients ignoring our rejection can't keep us alive.
      return
    end
    
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
    
    We can only do this if we've already received and stored a _NameTokensFn.
    """
    try
      let fn = _deltas_fn as _NameTokensFn
      let now = Time.millis()
      if (now - 500) >= _last_proactive then
        fn(_name, _repo.flush_deltas())
        _last_proactive = now
      end
    end
  
  fun ref flush_deltas(fn: _NameTokensFn) =>
    _deltas_fn = fn
    if not _repo.delta_empty() then
      fn(_name, _repo.flush_deltas())
    end
  
  fun ref converge_deltas(deltas: crdt.TokensIterator iso) =>
    try
      _repo.converge(consume deltas)?
      // TODO: print error when deltas fail to parse
    end
  
  fun ref clean_shutdown(promise: Promise[None]) =>
    """
    When told to shut down, we do a few things:
      - set _shutdown flag to true so that we stop accepting requests.
      - flush our remaining deltas to the other members of the cluster.
      - TODO: disk persistence?
    
    Once we've completed all these actions locally (or at initiated them),
    the promise passed as an argument will be fulfilled.
    """
    _shutdown = true
    try flush_deltas(_deltas_fn as _NameTokensFn) end
    // TODO: disk persistence?
    promise(None)
