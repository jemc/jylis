use "net"

class iso ClusterListenNotify is TCPListenNotify
  let _cluster: Cluster
  new iso create(cluster': Cluster) => _cluster = cluster'
  fun ref not_listening(listen: _Listen ref) => _cluster._listen_failed()
  fun ref listening(listen: _Listen ref) => _cluster._listen_ready()
  fun ref connected(listen: _Listen ref): FramedNotify^ =>
    let inner: TCPConnectionNotify iso = ClusterNotify(_cluster)
    FramedNotify(consume inner)
