use "net"
use "resp"

primitive _OutNone
  fun tag write(data: ByteSeq) => None
  fun tag writev(data: ByteSeqIter) => None

class iso ServerNotify is TCPConnectionNotify
  let _server: Server
  var _parser: CommandParser
  var _resp: Respond = Respond(_OutNone)
  
  new iso create(server': Server) =>
    _server = server'
    _parser = CommandParser({(_) => None })
  
  fun ref _init(conn: _Conn ref) =>
    _resp = Respond(conn)
    _parser = CommandParser({(proto_err)(resp = _resp) =>
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
    for cmd in _parser do _server(_resp, cmd) end
    true // TODO?
