use "collections"
use "crdt"
use "logger"

actor Cluster
  let _auth: AmbientAuth // TODO: de-escalate to NetAuth
  let _log: Logger[String]
  let _my_addr: Address
  let _serial: _Serialise
  let _listen: _Listen
  let _known_addrs: P2Set[Address]  = _known_addrs.create()
  let _passives: SetIs[_Conn]       = _passives.create()
  let _actives: Map[Address, _Conn] = _actives.create()
  
  new create(
    auth': AmbientAuth,
    log': Logger[String],
    my_addr': Address,
    known_addrs': Array[Address] val)
  =>
    _auth = auth'
    _log = log'
    _my_addr = my_addr'
    _serial = _Serialise(auth')
    
    let listen_notify = ClusterListenNotify(this, _serial.signature())
    _listen = _Listen(auth', consume listen_notify, "", my_addr'.port)
    
    _known_addrs.set(my_addr')
    _known_addrs.union(known_addrs'.values())
    _sync_actives()
  
  be dispose() =>
    _listen.dispose()
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
  
  fun ref _reconnect_active(conn: _Conn tag) =>
    conn.dispose()
    for (addr, conn') in _actives.pairs() do
      if conn is conn' then
        let notify = FramedNotify(ClusterNotify(this, _serial.signature()))
        _actives(addr) = _Conn(_auth, consume notify, addr.host, addr.port)
        break
      end
    end
  
  be _listen_failed() =>
    _log(Warn) and _log.log("listen failed")
  
  be _listen_ready() => None
    _log(Info) and _log.log("listen ready")
  
  be _passive_accepted(conn: _Conn tag) =>
    _log(Info) and _log.log("passive connection accepted")
    _passives.set(conn)
  
  be _active_initiated(conn: _Conn tag) =>
    _log(Info) and _log.log("active connection initiated")
    _send(conn, MsgAnnounceAddrs(_known_addrs))
  
  be _active_missed(conn: _Conn tag) =>
    _log(Warn) and _log.log("active connection missed")
    _reconnect_active(conn) // TODO: after delay
  
  be _passive_lost(conn: _Conn tag) =>
    _log(Warn) and _log.log("passive connection lost")
  
  be _active_lost(conn: _Conn tag) =>
    _log(Warn) and _log.log("active connection lost")
    // TODO: _reconnect_active(conn) after delay
  
  be _passive_error(conn: _Conn tag, message: String) =>
    _log(Warn) and _log.log("passive connection error: " + message)
    // TODO: disconnect?
  
  be _active_error(conn: _Conn tag, message: String) =>
    _log(Warn) and _log.log("active connection error: " + message)
    // TODO: _reconnect_active(conn) after delay
  
  be _passive_frame(conn: _Conn tag, data: Array[U8] val) =>
    try
      let msg = _serial.from_bytes[Msg](data)?
      _log(Fine) and _log.log("received " + msg.string())
      _passive_msg(conn, msg)
    else
      _passive_error(conn, "invalid message on passive connection")
    end
  
  be _active_frame(conn: _Conn tag, data: Array[U8] val) =>
    try
      let msg = _serial.from_bytes[Msg](data)?
      _log(Fine) and _log.log("received " + msg.string())
      _active_msg(conn, msg)
    else
      _active_error(conn, "invalid message on active connection")
    end
  
  fun ref _send(conn: _Conn tag, msg: Msg) =>
    _log(Fine) and _log.log("sending " + msg.string())
    try conn.write(_serial.to_bytes(msg)?)
    else _log(Error) and _log.log("failed to serialise message")
    end
  
  fun ref _converge_addrs(received_addrs: P2Set[Address] box) =>
    _known_addrs.converge(received_addrs)
    _sync_actives()
  
  fun ref _passive_msg(conn: _Conn tag, msg': Msg) =>
    match msg'
    | let msg: MsgAnnounceAddrs =>
      _converge_addrs(msg.known_addrs)
      _send(conn, MsgRespondAddrs(_known_addrs))
    else
      _passive_error(conn, "unhandled message: " + msg'.string())
    end
  
  fun ref _active_msg(conn: _Conn tag, msg': Msg) =>
    match msg'
    | let msg: MsgRespondAddrs =>
      _converge_addrs(msg.known_addrs)
    else
      _active_error(conn, "unhandled message: " + msg'.string())
    end
