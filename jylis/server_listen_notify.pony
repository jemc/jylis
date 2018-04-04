use "net"

class iso ServerListenNotify is TCPListenNotify
  let _server: Server
  let _database: Database
  new iso create(server': Server, database': Database) =>
    (_server, _database) = (server', database')
  
  fun ref not_listening(listen: _Listen ref) =>
    _server._listen_failed()
  
  fun ref listening(listen: _Listen ref) =>
    _server._listen_ready()
  
  fun ref connected(listen: _Listen ref): ServerNotify^ =>
    ServerNotify(_database)
