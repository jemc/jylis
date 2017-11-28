use "collections"
use "logger"

actor Cluster
  let _auth: AmbientAuth // TODO: de-escalate to NetAuth
  let _log: Logger[String]
  let _my_addr: PeerAddr
  let _serial: _Serialise
  let _listen: _Listen
  let _known_addrs: PeerAddrP2Set = _known_addrs.create()
  let _peers: MapIs[_Conn, Peer] = _peers.create()
  
  new create(
    auth': AmbientAuth,
    log': Logger[String],
    my_addr': PeerAddr,
    known_addrs': Array[PeerAddr] val)
  =>
    _auth = auth'
    _log = log'
    _my_addr = my_addr'
    _serial = _Serialise(auth')
    
    let listen_notify = ClusterListenNotify(this, _serial.signature())
    _listen = _Listen(auth', consume listen_notify, "", my_addr'._2)
    
    for a in known_addrs'.values() do
      _known_addrs.set(a)
      let notify = FramedNotify(ClusterNotify(this, _serial.signature()))
      _peers(_Conn(_auth, consume notify, a._1, a._2)) = Peer(a)
    end
  
  be dispose() =>
    _listen.dispose()
    for conn in _peers.keys() do conn.dispose() end
  
  be _listen_failed() =>
    _log(Warn) and _log.log("listen failed")
  
  be _listen_ready() => None
    _log(Info) and _log.log("listen ready")
  
  be _passive_accepted(conn: _Conn tag) =>
    _log(Info) and _log.log("passive connection accepted")
    _peers(conn) = Peer(("", "", ""))
  
  be _active_initiated(conn: _Conn tag) =>
    _log(Info) and _log.log("active connection initiated")
    _send_announce_addrs(conn)
  
  be _active_missed(conn: _Conn tag) =>
    _log(Warn) and _log.log("active connection missed")
    // TODO: exponential backoff before retry?
    try let a = _peers.remove(conn)?._2.addr
      let notify = FramedNotify(ClusterNotify(this, _serial.signature()))
      _peers(_Conn(_auth, consume notify, a._1, a._2)) = Peer(a)
    end
  
  be _passive_lost(conn: _Conn tag) =>
    _log(Warn) and _log.log("passive connection lost")
  
  be _active_lost(conn: _Conn tag) =>
    _log(Warn) and _log.log("active connection lost")
  
  be _passive_error(conn: _Conn tag, message: String) =>
    _log(Warn) and _log.log("passive connection error: " + message)
  
  be _active_error(conn: _Conn tag, message: String) =>
    _log(Warn) and _log.log("active connection error: " + message)
  
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
  
  fun ref _send_announce_addrs(conn: _Conn tag) =>
    _send(conn, MsgAnnounceAddrs(_my_addr, _known_addrs))
  
  fun ref _converge_addrs(received_addrs: PeerAddrP2Set box) =>
    // TODO: compare to active connections that we're currently maintaining;
    // add ones that we don't have a connection for, and remove ones that we do.
    _known_addrs.converge(received_addrs)
  
  fun ref _passive_msg(conn: _Conn tag, msg': Msg) =>
    match msg'
    | let msg: MsgAnnounceAddrs =>
      // TODO: deal with msg.my_addr appropriately? review protocol design doc
      _known_addrs.converge(msg.known_addrs)
      _send(conn, MsgRespondAddrs(_known_addrs))
    else
      _passive_error(conn, "unhandled message: " + msg'.string())
    end
  
  fun ref _active_msg(conn: _Conn tag, msg': Msg) =>
    match msg'
    | let msg: MsgRespondAddrs =>
      _known_addrs.converge(msg.known_addrs)
    else
      _active_error(conn, "unhandled message: " + msg'.string())
    end
