use "net"

type _Listen is TCPListener

class iso ClusterListenNotify is TCPListenNotify
  let _cluster: Cluster
  let _signature: Array[U8] val
  new iso create(cluster': Cluster, signature': Array[U8] val) =>
    (_cluster, _signature) = (cluster', signature')
  
  fun ref not_listening(listen: TCPListener ref) => _cluster._listen_failed()
  fun ref listening(listen: TCPListener ref) => _cluster._listen_ready()
  fun ref connected(listen: TCPListener ref): FramedNotify^ =>
    let inner: TCPConnectionNotify iso = ClusterNotify(_cluster, _signature)
    FramedNotify(consume inner)
