use "net"
use "resp"

primitive _OutNone
  fun tag write(data: ByteSeq) => None
  fun tag writev(data: ByteSeqIter) => None

class iso ServerNotify is TCPConnectionNotify
  let _server: Server
  var _parser: Parser
  var _resp: Respond = Respond(_OutNone)
  
  new iso create(server': Server) =>
    _server = server'
    _parser = Parser({(_) => None })
  
  fun ref _init(conn: _Conn ref) =>
    _resp = Respond(conn)
    _parser = Parser({(proto_err)(resp = _resp) =>
      resp.err(proto_err)
      conn.dispose()
    })
  
  fun ref accepted(conn: _Conn ref) => _resp = Respond(conn)
  fun ref connected(conn: _Conn ref) => _resp = Respond(conn)
  
  fun ref connect_failed(c: _Conn ref) => None // we only accept, never connect
  
  fun ref closed(conn: _Conn ref) => None // TODO?
  fun ref throttled(conn: _Conn ref) => None // TODO?
  fun ref unthrottled(conn: _Conn ref) => None // TODO?
  
  fun ref received(conn: _Conn ref, data: Array[U8] val, times: USize): Bool =>
    _parser.append(data)
    while _parser.has_next() do
      // TODO: remove `as`, refactor to `for` and fix the pony segfault.
      try let cmd = _parser.next()? as ElementsAny
        _server(cmd, _resp)
      end
    end
    true // TODO?
