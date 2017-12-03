use "net"

class iso ClusterListenNotify is TCPListenNotify
  let _cluster: Cluster
  let _signature: Array[U8] val
  new iso create(cluster': Cluster, signature': Array[U8] val) =>
    (_cluster, _signature) = (cluster', signature')
  
  fun ref not_listening(listen: _Listen ref) => _cluster._listen_failed()
  fun ref listening(listen: _Listen ref) => _cluster._listen_ready()
  fun ref connected(listen: _Listen ref): FramedNotify^ =>
    let inner: TCPConnectionNotify iso = ClusterNotify(_cluster, _signature)
    FramedNotify(consume inner)
