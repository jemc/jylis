use "time"
use "promises"
use crdt = "crdt"
use "resp"

interface RepoAny
  new ref create(identity': U64)
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool?
  fun ref delta_empty(): Bool
  fun ref flush_deltas(): crdt.Tokens
  fun ref data_tokens(): crdt.Tokens
  fun ref history_tokens(): crdt.Tokens
  fun ref converge(tokens: crdt.TokensIterator)?
  fun ref compare_history(tokens: crdt.TokensIterator): (Bool, Bool)?

interface tag RepoManagerAny
  be apply(resp: Respond, cmd: Array[String] val)
  be flush_deltas(fn: _NameTokensFn)
  be converge_deltas(deltas: crdt.TokensIterator iso)
  be send_data(send_fn: _NameTokensFn)
  be send_history(send_fn: _NameTokensFn)
  be compare_history(
    history: crdt.TokensIterator iso,
    send_fn: _NameTokensFn,
    need_fn: _NameFn)
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
  
  be send_data(send_fn: _NameTokensFn) =>
    _core.send_data(send_fn)
  
  be send_history(send_fn: _NameTokensFn) =>
    _core.send_history(send_fn)
  
  be compare_history(
    history: crdt.TokensIterator iso,
    send_fn: _NameTokensFn,
    need_fn: _NameFn)
  =>
    _core.compare_history(consume history, send_fn, need_fn)
  
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
  
  fun ref send_data(send_fn: _NameTokensFn) =>
    // TODO: tokenizing the whole repo at once may not be a good idea if the
    // data set is very large in memory - consider alternatives.
    send_fn(_name, _repo.data_tokens())
  
  fun ref send_history(send_fn: _NameTokensFn) =>
    send_fn(_name, _repo.history_tokens())
  
  fun ref compare_history(
    history: crdt.TokensIterator iso,
    send_fn: _NameTokensFn,
    need_fn: _NameFn)
  =>
    try
      // TODO: print error when history fail to parse
      (let have_more, let need_more) =
        _repo.compare_history(consume history)?
      
      if have_more then send_fn(_name, _repo.history_tokens()) end
      if need_more then need_fn(_name) end
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
