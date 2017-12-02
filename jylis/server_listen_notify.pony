use "net"

class iso ServerListenNotify is TCPListenNotify
  let _server: Server
  new iso create(server': Server) => _server = server'
  
  fun ref not_listening(listen: TCPListener ref) => _server._listen_failed()
  fun ref listening(listen: TCPListener ref) => _server._listen_ready()
  fun ref connected(listen: TCPListener ref): ServerNotify^ =>
    ServerNotify(_server)
