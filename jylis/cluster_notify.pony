use "net"

type _Conn is TCPConnection

class iso ClusterNotify is TCPConnectionNotify
  let _cluster: Cluster
  let _signature: Array[U8] val
  var _passive: Bool = false
  var _established: Bool = false
  
  new iso create(cluster': Cluster, signature': Array[U8] val) =>
    (_cluster, _signature) = (cluster', signature')
  
  fun ref accepted(conn: _Conn ref) =>
    _passive = true
  
  fun ref connected(conn: _Conn ref) =>
    _passive = false
    conn.write(_signature)
  
  fun ref connect_failed(conn: _Conn ref) =>
    _cluster._peer_missed(conn)
  
  fun ref auth_failed(conn: _Conn ref) =>
    _cluster._peer_error(conn, "misaligned framing header in protocol")
  
  fun ref closed(conn: TCPConnection ref) =>
    _cluster._peer_lost(conn)
  
  fun ref throttled(conn: TCPConnection ref) => None // TODO
  fun ref unthrottled(conn: TCPConnection ref) => None // TODO
  
  fun ref received(conn: _Conn ref, data: Array[U8] val, times: USize): Bool =>
    if not _established then
      if _passive then conn.write(_signature) end
      
      if (_signature.size() == data.size()) and
        for (idx, byte) in data.pairs() do
          try if _signature(idx)? != byte then error end
          else break false
          end
          true
        else false
        end
      then
        _established = true
        if _passive
        then _cluster._peer_accepted(conn)
        else _cluster._peer_connected(conn)
        end
      else
        _cluster._peer_error(conn, "invalid serialise signature")
        conn.dispose() // TODO: time delay? review protocol design and decide...
      end
    else
      _cluster._peer_frame(conn, consume data)
    end
    true
