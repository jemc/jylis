use "collections"
use "net"
use "crdt"
use "inspect"

actor Cluster
  let _auth: NetAuth
  let _log: Log
  let _system: System
  let _my_addr: Address
  let _database: Database
  let _disk: DiskAny
  let _listen: _Listen
  let _heart: Heart
  let _deltas_fn: _NameTokensFn
  var _tick: U64                        = 0
  let _known_addrs: P2Set[Address]      = _known_addrs.create()
  let _passives: SetIs[_Conn]           = _passives.create()
  let _actives: Map[Address, _Conn]     = _actives.create()
  let _last_activity: MapIs[_Conn, U64] = _last_activity.create()
  
  new create(
    auth': AmbientAuth,
    config': System,
    database': Database,
    disk': DiskAny)
  =>
    _auth     = NetAuth(auth')
    _system   = config'
    _database = database'
    _disk     = disk'
    
    _log     = _system.log
    _my_addr = _system.config.addr
    
    let listen_notify = ClusterListenNotify(this)
    _listen = _Listen(auth', consume listen_notify, "", _my_addr.port)
    
    _heart = Heart(this, (_system.config.heartbeat_time * 1_000_000_000).u64())
    
    _deltas_fn =
      try  this~broadcast_deltas_with_disk(_disk as Disk)
      else this~broadcast_deltas()
      end
    
    _known_addrs.set(_my_addr)
    _known_addrs.union(_system.config.seed_addrs.values())
    
    _heartbeat()
  
  be dispose() =>
    _log.info() and _log.i("cluster listener shutting down")
    _listen.dispose()
    _heart.dispose()
    for conn in _actives.values() do conn.dispose() end
    for conn in _passives.values() do conn.dispose() end
  
  fun ref _sync_actives() =>
    """
    Make sure that active connections are being attempted for all known
    addresses and abort connections for addresses that have been removed.
    """
    for addr in _actives.keys() do
      if _known_addrs.contains(addr) then continue end
      
      _log.info() and _log.i("forgetting old address: " + addr.string())
      
      try _actives.remove(addr)?._2.dispose() end
    end
    
    for addr in _known_addrs.values() do
      if (_my_addr == addr) or _actives.contains(addr) then continue end
      
      _log.info() and _log.i("connecting to address: " + addr.string())
      
      let notify = FramedNotify(ClusterNotify(this))
      _actives(addr) = _Conn(_auth, consume notify, addr.host, addr.port)
    end
  
  fun ref _find_active(conn: _Conn tag): Address? =>
    """
    Find the connect address for the given active connection reference.
    Raises an error if the connection reference was not in the map.
    """
    for (addr, conn') in _actives.pairs() do
      if conn is conn' then return addr end
    end
    error
  
  fun ref _remove_passive(conn: _Conn tag) =>
    """
    Stop the given passive connection and remove it from our mappings.
    If the other side of the connection cares, they can connect to us again.
    """
    conn.dispose()
    _passives.unset(conn)
    try _last_activity.remove(conn)? end
  
  fun ref _remove_active(conn: _Conn tag) =>
    """
    Stop the given active connection and remove it from our mappings.
    Let it be created again later the next time _sync_actives is called.
    """
    conn.dispose()
    try _actives.remove(_find_active(conn)?)? end
    try _last_activity.remove(conn)? end
  
  fun ref _remove_either(conn: _Conn tag) =>
    """
    Stop the given connection and remove it from our mappings.
    This method will work for either an active or passive connection.
    """
    if _passives.contains(conn)
    then _remove_passive(conn)
    else _remove_active(conn)
    end
  
  be _heartbeat() =>
    """
    Receive the periodic message from the Heart we're holding,
    and take some general housekeeping/timekeeping actions here.
    """
    _tick = _tick + 1
    
    // Close connections that have been inactive for 10 or more ticks.
    for (conn, last_tick) in _last_activity.pairs() do
      if (last_tick + 10) < _tick then _remove_either(conn) end
    end
    
    // On every third tick, announce our addresses to other nodes.
    if (_tick % 3) == 0 then
      let data = MsgAnnounceAddrs.to_wire(_known_addrs)
      for conn in _actives.values() do
        _send(conn, data)
      end
    end
    
    // On every tick, flush deltas to other nodes.
    _database.flush_deltas(_deltas_fn)
    
    // On every tick, sync active connections.
    _sync_actives()
  
  be _listen_failed() =>
    _log.err() and _log.e(
      "cluster listener failed to listen on port " + _my_addr.port
    )
    _system.dispose()
  
  be _listen_ready() => None
    _log.info() and _log.i(
      "cluster listener ready with address " + _my_addr.string()
    )
  
  be _passive_established(conn: _Conn tag, remote_addr: Address) =>
    _log.info() and _log.i("passive cluster connection established from: " +
      remote_addr.string())
    
    _passives.set(conn)
    _last_activity(conn) = _tick
    
    // Send our known history to compare notes with the other node.
    let this_tag: Cluster tag = this
    _database.send_all_history(this_tag~send_compare_history(conn, _log))
  
  be _active_established(conn: _Conn tag) =>
    _log.info() and _log.i("active cluster connection established to: " +
      try _find_active(conn)?.string() else "" end)
    
    _send(conn, MsgExchangeAddrs.to_wire(_known_addrs))
    _last_activity(conn) = _tick
  
  be _active_missed(conn: _Conn tag) =>
    _log.warn() and _log.w("active cluster connection missed: " +
      try _find_active(conn)?.string() else "" end)
    
    _remove_active(conn)
  
  be _passive_lost(conn: _Conn tag) =>
    _log.warn() and _log.w("passive cluster connection lost")
    _remove_passive(conn)
  
  be _active_lost(conn: _Conn tag) =>
    _log.warn() and _log.w("active cluster connection lost: " +
      try _find_active(conn)?.string() else "" end)
    
    _remove_active(conn)
  
  be _passive_error(conn: _Conn tag, a: String, b: String) =>
    _log.warn() and _log.w("passive cluster connection error: " + a + "; " + b)
    _remove_passive(conn)
  
  be _active_error(conn: _Conn tag, a: String, b: String) =>
    _log.warn() and _log.w("active cluster connection error: " + a + "; " + b)
    _remove_active(conn)
  
  be _passive_frame(conn: _Conn tag, data: Array[U8] val) =>
    let iter = DatabaseCodecIn([data])
    try
      _log.debug() and _log.d("received " + Inspect(String.from_array(data)))
      _passive_msg(conn, consume iter, data)?
    else
      _passive_error(conn, "invalid message on passive cluster connection", "")
    end
  
  be _active_frame(conn: _Conn tag, data: Array[U8] val) =>
    let iter = DatabaseCodecIn([data])
    try
      _log.debug() and _log.d("received " + Inspect(String.from_array(data)))
      _active_msg(conn, consume iter)?
    else
      _active_error(conn, "invalid message on active cluster connection", "")
    end
  
  fun ref _send(conn: _Conn tag, data: Array[ByteSeq] val) =>
    _log.debug() and _log.d("sending " + Inspect(data))
    conn.writev(data)
  
  fun tag _sendt(conn: _Conn tag, log: Log, data: Array[ByteSeq] val) =>
    log.debug() and log.d("sending " + Inspect(data))
    conn.writev(data)
  
  be _broadcast_writev(data: Array[ByteSeq] val) =>
    _log.debug() and _log.d("broadcasting " + Inspect(data))
    for conn in _actives.values() do conn.writev(data) end
  
  fun tag broadcast_deltas(name: String, tokens: Tokens box) =>
    let data = DatabaseCodecOut(tokens.iterator())
    _broadcast_writev(MsgPushData.to_wire(name) .> append(data))
  
  fun tag broadcast_deltas_with_disk(
    disk: Disk,
    name: String,
    delta: Tokens box)
  =>
    let data = DatabaseCodecOut(delta.iterator())
    disk.append_writev(name, data)
    _broadcast_writev(MsgPushData.to_wire(name) .> append(data))
  
  fun tag send_push_data(
    conn: _Conn tag,
    log: Log,
    name: String,
    deltas: Tokens box)
  =>
    let data = DatabaseCodecOut(deltas.iterator())
    _sendt(conn, log, MsgPushData.to_wire(name) .> append(data))
  
  fun tag send_request_dump(conn: _Conn tag, log: Log, name: String) =>
    _sendt(conn, log, MsgRequestDump.to_wire(name))
  
  fun tag send_compare_history(
    conn: _Conn tag, 
    log: Log,
    name: String,
    history: Tokens box)
  =>
    let data = DatabaseCodecOut(history.iterator())
    _sendt(conn, log, MsgCompareHistory.to_wire(name) .> append(data))
  
  fun tag broadcast_history(name: String, history: Tokens box) =>
    let data = DatabaseCodecOut(history.iterator())
    _broadcast_writev(MsgCompareHistory.to_wire(name) .> append(data))
  
  fun ref _converge_addrs(received_addrs: P2Set[Address] box) =>
    if _known_addrs.converge(received_addrs) then
      // Find any other addrs that have the same host and port as we do.
      // By our own assertion, they are outdated and need to be blacklisted.
      let blacklist = Array[Address]
      for addr in _known_addrs.values() do
        if (addr.host == _my_addr.host)
        and (addr.port == _my_addr.port)
        and (addr.name != _my_addr.name)
        then blacklist.push(addr)
        end
      end
      for addr in blacklist.values() do
        _log.info() and _log.i("blacklisting outdated address: " + addr.string())
        _known_addrs.unset(addr)
      end
      
      // Shut down the process if our own address has been blacklisted.
      if not _known_addrs.contains(_my_addr) then
        _log.err() and _log.e("can't continue due to being blacklisted")
        _log.info() and _log.i("this node must be run under a different name")
        _system.dispose()
        return
      end
      
      // Refresh our active connections based on these updated addresses.
      _sync_actives()
      
      // Also notify other nodes we're connected to of our updated addresses.
      let data = MsgExchangeAddrs.to_wire(_known_addrs)
      for conn in _actives.values() do
        _send(conn, data)
      end
    end
  
  fun ref _passive_msg(
    conn: _Conn tag,
    iter: DatabaseCodecInIterator iso,
    orig: Array[U8] val)
    ?
  =>
    _last_activity(conn) = _tick
    let this_tag: Cluster tag = this
    (let msg', let rest) = Msg.from_wire(consume iter)?
    match msg'
    | let msg: MsgExchangeAddrs =>
      let known_addrs = msg.from_wire(consume rest)?
      _converge_addrs(known_addrs)
      _send(conn, MsgExchangeAddrs.to_wire(_known_addrs))
    | let msg: MsgAnnounceAddrs =>
      let known_addrs = msg.from_wire(consume rest)?
      _converge_addrs(known_addrs)
      _send(conn, MsgPong.to_wire())
    | let msg: MsgPushData =>
      (let name, let rest') = msg.from_wire(consume rest)?
      _database.converge_deltas(name, consume rest')
      
      // TODO: avoid this brittle hack for removing Msg prefix from the frame.
      let trimmed = String.from_array(orig).trim(
        23 + name.size().string().size() + name.size()).array()
      _disk.append_write(name, trimmed)
      
      _send(conn, MsgPong.to_wire())
    | let msg: MsgCompareHistory =>
      (let name, let rest') = msg.from_wire(consume rest)?
      // TODO: don't immediately send the dump request here as the 2nd response.
      // We want to control the number of dump requests we have outbound at a
      // given time, so that they don't flood us with memory at the same time.
      _send(conn, MsgRequestDump.to_wire(name))
      // _database.compare_history(name, consume rest',
      //   _NameTokensFnNone,
      //   this_tag~send_request_dump(conn, _log))
    else
      _passive_error(conn, "unhandled cluster message", msg'.name())
    end
  
  fun ref _active_msg(conn: _Conn tag, iter: DatabaseCodecInIterator iso)? =>
    _last_activity(conn) = _tick
    let this_tag: Cluster tag = this
    (let msg', let rest) = Msg.from_wire(consume iter)?
    match msg'
    | let msg: MsgPong => None
    | let msg: MsgExchangeAddrs =>
      let known_addrs = msg.from_wire(consume rest)?
      _converge_addrs(known_addrs)
    | let msg: MsgRequestDump =>
      let name = msg.from_wire(consume rest)?
      _database.send_data(name, this_tag~send_push_data(conn, _log))
    | let msg: MsgCompareHistory =>
      (let name, let rest') = msg.from_wire(consume rest)?
      _database.compare_history(name, consume rest',
        this_tag~send_compare_history(conn, _log),
        _NameFnNone) // TODO: do something here?
    else
      _active_error(conn, "unhandled cluster message", msg'.name())
    end
