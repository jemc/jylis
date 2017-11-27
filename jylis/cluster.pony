use "collections"
use "logger"

actor Cluster
  let _auth: AmbientAuth // TODO: de-escalate to NetAuth
  let _log: Logger[String]
  let _advert_addr: PeerAddr
  let _serial: _Serialise
  let _listen: _Listen
  let _peer_addrs: PeerAddrP2Set = _peer_addrs.create()
  let _peers: MapIs[_Conn, Peer] = _peers.create()
  
  new create(
    auth': AmbientAuth,
    log': Logger[String],
    advert_addr': PeerAddr,
    peer_addrs': Array[PeerAddr] val)
  =>
    _auth = auth'
    _log = log'
    _advert_addr = advert_addr'
    _serial = _Serialise(auth')
    
    let listen_notify = PeerListenNotify(this, _serial.signature())
    _listen = _Listen(auth', consume listen_notify, "", advert_addr'._2)
    
    for a in peer_addrs'.values() do
      _peer_addrs.set(a)
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
  
  be _peer_accepted(conn: _Conn tag) =>
    _log(Info) and _log.log("peer accepted")
    _peers(conn) = Peer(("", "", ""))
  
  be _peer_connected(conn: _Conn tag) =>
    _log(Info) and _log.log("peer connected")
  
  be _peer_missed(conn: _Conn tag) =>
    // TODO: exponential backoff before retry?
    try let a = _peers.remove(conn)?._2.addr
      let notify = FramedNotify(ClusterNotify(this, _serial.signature()))
      _peers(_Conn(_auth, consume notify, a._1, a._2)) = Peer(a)
    end
    _log(Warn) and _log.log("peer missed")
  
  be _peer_lost(conn: _Conn tag) =>
    _log(Warn) and _log.log("peer lost")
  
  be _peer_error(conn: _Conn tag, message: String) =>
    _log(Warn) and _log.log("peer error: " + message)
  
  be _peer_frame(conn: _Conn tag, data: Array[U8] val) =>
    try _peer_msg(conn, _serial.from_bytes[PeerMsg](data)?)
    else _peer_error(conn, "invalid serialised PeerMsg")
    end
  
  fun ref _send(conn: _Conn tag, msg: PeerMsg) =>
    try conn.write(_serial.to_bytes(msg)?)
    else _peer_error(conn, "failed to serialise PeerMsg")
    end
  
  fun ref _send_hello(conn: _Conn tag) =>
    _log(Fine) and _log.log("sending hello")
    _send(conn, PeerMsgHello(_advert_addr, _peer_addrs))
  
  fun ref _peer_msg(conn: _Conn tag, msg': PeerMsg) =>
    match msg'
    | let msg: PeerMsgHello => _log(Fine) and _log.log("received hello")
    end
