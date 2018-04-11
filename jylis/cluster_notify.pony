use "net"

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
        then _cluster._passive_established(conn)
        else _cluster._active_established(conn)
        end
      else
        if _passive
        then _cluster._passive_error(conn, "invalid serialise signature", "")
        else _cluster._active_error(conn, "invalid serialise signature", "")
        end
        conn.dispose() // TODO: time delay? review protocol design and decide...
      end
    else
      if _passive
      then _cluster._passive_frame(conn, consume data)
      else _cluster._active_frame(conn, consume data)
      end
    end
    true
