use "signals"

actor Dispose
  let _database: Database
  let _server: Server
  let _cluster: Cluster
  var _disposing: Bool = false
  
  new create(database': Database, server': Server, cluster': Cluster) =>
    (_database, _server, _cluster) = (database', server', cluster')
  
  be dispose() =>
    if not _disposing then
      _disposing = true
      _database.clean_shutdown().next[None]({(_) =>
        _server.dispose()
        _cluster.dispose()
      })
    end
  
  fun tag on_signal() =>
    """
    Register a signal handler for SIGINT and SIGTERM that will call dispose.
    """
    SignalHandler(_sig_notify(), Sig.int())
    SignalHandler(_sig_notify(), Sig.term())
  
  fun tag _sig_notify(): SignalNotify iso^ =>
    object iso is SignalNotify
      let that: Dispose = this
      fun ref apply(count: U32): Bool => that.dispose()
        true
    end
