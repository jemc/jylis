use "net"

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
  
  Events are reported back to the wrapped TCPConnectionNotify object, which
  will get an entire frame passed to each call of its `received` method.
  """
  let _notify: TCPConnectionNotify
  var _expect: USize = 0
  
  new iso create(notify': TCPConnectionNotify iso) => _notify = consume notify'
  
  fun ref accepted(conn: _Conn ref) =>
    _notify.accepted(conn)
    _expect_framing(conn)
  
  fun ref connecting(conn: _Conn ref, count: U32) =>
    _notify.connecting(conn, count)
  
  fun ref connected(conn: _Conn ref) =>
    _notify.connected(conn)
    _expect_framing(conn)
  
  fun ref connect_failed(conn: _Conn ref) => _notify.connect_failed(conn)
  fun ref auth_failed(conn: _Conn ref) => _notify.auth_failed(conn)
  fun ref closed(conn: _Conn ref) => _notify.closed(conn)
  fun ref throttled(conn: _Conn ref) => _notify.throttled(conn)
  fun ref unthrottled(conn: _Conn ref) => _notify.unthrottled(conn)
  
  fun ref _expect_framing(conn: _Conn ref) =>
    _expect = 0
    conn.expect(Framing.header_size())
  
  fun ref _expect_bytes(conn: _Conn ref, size: USize) =>
    _expect = size
    conn.expect(size)
  
  fun ref sent(conn: _Conn ref, data: ByteSeq): ByteSeq =>
    conn.write_final(Framing.write_header(data.size()))
    // TODO: call _notify.sent?
    data
  
  fun ref sentv(conn: _Conn ref, array: ByteSeqIter): ByteSeqIter =>
    var size: USize = 0
    for data in array.values() do size = size + data.size() end
    conn.write_final(Framing.write_header(size))
    // TODO: call _notify.sentv?
    array
  
  fun ref expect(conn: _Conn ref, qty: USize): USize =>
    // Disregard the requested expect - just reassert our own current choice.
    if _expect == 0 then Framing.header_size() else _expect end
  
  fun ref received(conn: _Conn ref, data: Array[U8] iso, times: USize): Bool =>
    if _expect == 0 then
      try _expect_bytes(conn, Framing.parse_header(consume data)?)
      else _notify.auth_failed(conn)
      end
      true
    else
      _expect_framing(conn)
      _notify.received(conn, consume data, times)
    end
