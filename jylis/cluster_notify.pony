use "net"

class iso ClusterNotify is TCPConnectionNotify
  let _cluster: Cluster
  var _passive: Bool = false
  var _established: Bool = false
  
  new iso create(cluster': Cluster) =>
    _cluster = cluster'
  
  fun ref accepted(conn: _Conn ref) =>
    _passive = true
    _cluster._passive_established(conn, _remote_addr(conn))
  
  fun ref connected(conn: _Conn ref) =>
    _passive = false
    _cluster._active_established(conn)
  
  fun ref connect_failed(conn: _Conn ref) =>
    _cluster._active_missed(conn)
  
  fun ref auth_failed(conn: _Conn ref) =>
    if _passive
    then _cluster._passive_error(conn, "misaligned framing in protocol", "")
    else _cluster._active_error(conn, "misaligned framing in protocol", "")
    end
  
  fun ref closed(conn: _Conn ref) =>
    if _passive
    then _cluster._passive_lost(conn)
    else _cluster._active_lost(conn)
    end
  
  fun ref throttled(conn: _Conn ref) => None // TODO
  fun ref unthrottled(conn: _Conn ref) => None // TODO
  
  fun ref received(conn: _Conn ref, data: Array[U8] val, times: USize): Bool =>
    if _passive
    then _cluster._passive_frame(conn, consume data)
    else _cluster._active_frame(conn, consume data)
    end
    true
  
  fun tag _remote_addr(conn: _Conn ref): Address =>
    (let remote_host, let remote_port) =
      try conn.remote_address().name()? else ("", "") end
    
    Address(remote_host, remote_port, "")
