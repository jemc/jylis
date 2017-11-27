use "net"

type _Conn is TCPConnection

class iso FramedNotify is TCPConnectionNotify
  """
  This notify class is a simple protocol layer on top of TCP that provides
  framing, allowing data to be read and written in discrete frames,
  rather than arbitrary chunks that may be concatenated or interrupted.
  
  The frame length is encoded as a short header that precedes the frame.
  
  The maximum length of a frame is the same as the maximum size of an Array.
  
  A frame may be written to the TCPConnection using the normal write and writev
  methods (for one frame and many frames, respectively), and this class will
  handle translating each byte buffer to an encoded frame "behind the scenes".
  
  All events are reported back to the Cluster, which "owns" the TCPConnection,
  including connection status updates, protocol errors, and frames received.
  """
  let _cluster: Cluster
  var _expect: USize = 0
  
  new iso create(cluster': Cluster) => _cluster = cluster'
  
  fun ref accepted(conn: _Conn ref) =>
    _cluster._peer_accepted(conn)
    _expect_framing(conn)
  
  fun ref connected(conn: _Conn ref) =>
    _cluster._peer_connected(conn)
    _expect_framing(conn)
  
  fun ref connect_failed(conn: _Conn ref) =>
    _cluster._peer_missed(conn)
  
  fun ref closed(conn: TCPConnection ref) =>
    _cluster._peer_lost(conn)
  
  fun ref throttled(conn: TCPConnection ref) => None // TODO
  fun ref unthrottled(conn: TCPConnection ref) => None // TODO
  
  fun ref _expect_framing(conn: _Conn ref) =>
    _expect = 0
    conn.expect(Framing.header_size())
  
  fun ref _expect_bytes(conn: _Conn ref, size: USize) =>
    _expect = size
    conn.expect(size)
  
  fun ref sent(conn: _Conn ref, data: ByteSeq): ByteSeq =>
    conn.write_final(Framing.write_header(data.size()))
    conn.write_final(data)
    ""
  
  fun ref sentv(conn: _Conn ref, array: ByteSeqIter): ByteSeqIter =>
    for data in array.values() do
      conn.write_final(Framing.write_header(data.size()))
      conn.write_final(data)
    end
    []
  
  fun ref received(conn: _Conn ref, data: Array[U8] iso, times: USize): Bool =>
    if _expect == 0 then
      try _expect_bytes(conn, Framing.parse_header(consume data)?)
      else _cluster._peer_error(conn, "misaligned framing header in protocol")
      end
    else
      _cluster._peer_frame(conn, consume data)
      _expect_framing(conn)
    end
    true
