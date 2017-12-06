use "collections"
use "crdt"

actor Cluster
  let _auth: AmbientAuth // TODO: de-escalate to NetAuth
  let _log: Log
  let _my_addr: Address
  let _server: Server
  let _serial: _Serialise
  let _listen: _Listen
  let _heart: Heart                     = Heart(this, 10_000_000_000) // 10s
  var _tick: U64                        = 0
  let _known_addrs: P2Set[Address]      = _known_addrs.create()
  let _passives: SetIs[_Conn]           = _passives.create()
  let _actives: Map[Address, _Conn]     = _actives.create()
  let _last_activity: MapIs[_Conn, U64] = _last_activity.create()
  
  new create(
    auth': AmbientAuth,
    log': Log,
    my_addr': Address,
    known_addrs': Array[Address] val,
    server': Server)
  =>
    _auth = auth'
    _log = log'
    _my_addr = my_addr'
    _server = server'
    _serial = _Serialise(auth')
    
    let listen_notify = ClusterListenNotify(this, _serial.signature())
    _listen = _Listen(auth', consume listen_notify, "", my_addr'.port)
    
    _known_addrs.set(my_addr')
    _known_addrs.union(known_addrs'.values())
    _sync_actives()
  
  be dispose() =>
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
      
      try _actives.remove(addr)?._2.dispose() end
    end
    
    for addr in _known_addrs.values() do
      if (_my_addr == addr) or _actives.contains(addr) then continue end
      
      let notify = FramedNotify(ClusterNotify(this, _serial.signature()))
      _actives(addr) = _Conn(_auth, consume notify, addr.host, addr.port)
    end
  
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
    for (addr, conn') in _actives.pairs() do
      if conn is conn' then
        try _actives.remove(addr)? end
        return
      end
    end
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
      for conn in _actives.values() do
        _send(conn, MsgAnnounceAddrs(_known_addrs))
      end
    end
    
    // On every tick, flush deltas to other nodes.
    _server.flush_deltas(this, _serial)
    
    // On every tick, sync active connections.
    _sync_actives()
  
  be _listen_failed() =>
    _log.err() and _log("listen failed")
    dispose()
  
  be _listen_ready() => None
    _log.info() and _log("listen ready")
  
  be _passive_accepted(conn: _Conn tag) =>
    _log.info() and _log("passive connection accepted")
    _passives.set(conn)
    _last_activity(conn) = _tick
  
  be _active_connected(conn: _Conn tag) =>
    _log.info() and _log("active connection connected")
    _last_activity(conn) = _tick
  
  be _passive_initiated(conn: _Conn tag) =>
    _log.info() and _log("passive connection initiated")
  
  be _active_initiated(conn: _Conn tag) =>
    _log.info() and _log("active connection initiated")
    _send(conn, MsgExchangeAddrs(_known_addrs))
  
  be _active_missed(conn: _Conn tag) =>
    _log.warn() and _log("active connection missed")
    _remove_active(conn)
  
  be _passive_lost(conn: _Conn tag) =>
    _log.warn() and _log("passive connection lost")
    _remove_passive(conn)
  
  be _active_lost(conn: _Conn tag) =>
    _log.warn() and _log("active connection lost")
    _remove_active(conn)
  
  be _passive_error(conn: _Conn tag, a: String, b: (String | None) = None) =>
    _log.warn() and _log("passive connection error", a, b)
    _remove_passive(conn)
  
  be _active_error(conn: _Conn tag, a: String, b: (String | None) = None) =>
    _log.warn() and _log("active connection error", a, b)
    _remove_active(conn)
  
  be _passive_frame(conn: _Conn tag, data: Array[U8] val) =>
    try
      let msg = _serial.from_bytes[Msg](data)?
      _log.fine() and _log("received", msg)
      _passive_msg(conn, msg)
    else
      _passive_error(conn, "invalid message on passive connection")
    end
  
  be _active_frame(conn: _Conn tag, data: Array[U8] val) =>
    try
      let msg = _serial.from_bytes[Msg](data)?
      _log.fine() and _log("received", msg)
      _active_msg(conn, msg)
    else
      _active_error(conn, "invalid message on active connection")
    end
  
  fun ref _send(conn: _Conn tag, msg: Msg box) =>
    _log.fine() and _log("sending", msg)
    try conn.write(_serial.to_bytes(msg)?)
    else _log.err() and _log("failed to serialise message")
    end
  
  be _broadcast_bytes(data: Array[U8] val) =>
    _log.fine() and _log("broadcasting data")
    for conn in _actives.values() do conn.write(data) end
  
  fun tag broadcast_deltas(
    serial: _Serialise,
    deltas: Array[(String, Array[(String, Any box)] box)] box)
  =>
    try _broadcast_bytes(serial.to_bytes(MsgPushDeltas(deltas))?) end
  
  fun ref _converge_addrs(received_addrs: P2Set[Address] box) =>
    if _known_addrs.converge(received_addrs) then
      _sync_actives()
      
      // Also notify other nodes we're connected to of our updated addresses.
      for conn in _actives.values() do
        _send(conn, MsgExchangeAddrs(_known_addrs))
      end
    end
  
  fun ref _passive_msg(conn: _Conn tag, msg': Msg) =>
    _last_activity(conn) = _tick
    match msg'
    | let msg: MsgExchangeAddrs =>
      _converge_addrs(msg.known_addrs)
      _send(conn, MsgExchangeAddrs(_known_addrs))
    | let msg: MsgAnnounceAddrs =>
      _converge_addrs(msg.known_addrs)
      _send(conn, MsgPong)
    | let msg: MsgPushDeltas =>
      _server.converge_deltas(msg.deltas)
      _send(conn, MsgPong)
    else
      _passive_error(conn, "unhandled message", msg'.string())
    end
  
  fun ref _active_msg(conn: _Conn tag, msg': Msg) =>
    _last_activity(conn) = _tick
    match msg'
    | let msg: MsgPong => None
    | let msg: MsgExchangeAddrs =>
      _converge_addrs(msg.known_addrs)
    else
      _active_error(conn, "unhandled message", msg'.string())
    end
