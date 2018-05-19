use "ponytest"
use ".."
use "bureaucracy"
use "files"

class TestDisk is UnitTest
  fun name(): String => "jylis.Disk"
  
  fun _tick(): F64 => 0.050 // 50ms
  
  fun _new_system(h: TestHelper, disk_dir: FilePath): System =>
    let config = Config
    config.disk_dir       = disk_dir
    config.addr           = Address.from_string("127.0.0.1:9990")
    config.heartbeat_time = _tick()
    config.log            = Log.create_err(h.env.out)
    System(consume config)
  
  fun apply(h: TestHelper)? =>
    h.long_test((20 * _tick() * 1_000_000_000).u64())
    let auth     = h.env.root as AmbientAuth
    let disk_dir = FilePath.mkdtemp(auth, "tmp/")?
    
    // Create a disk-persisted database.
    let system   = _new_system(h, disk_dir)
    let database = Database(system)
    let disk     = DiskSetup(system) .> replay(database)
    let cluster  = Cluster(auth, system, database, disk)
    let disposer = Custodian .> apply(disk) .> apply(cluster)
    
    let tick = _tick()
    _Wait(h, 3 * tick, {(h)(
      db = database, d = disposer,
      auth, disk_dir, system, tick)
    =>
      // Write some data to it then destroy it.
      db(_ExpectRespond(h, "+OK\r\n"), ["GCOUNT"; "INC"; "foo"; "2"])
      d.dispose()
      
      _Wait(h, 2 * tick, {(h)(auth, disk_dir, system, tick) =>
        // Create another database with the same disk directory.
        let database = Database(system)
        let disk     = DiskSetup(system) .> replay(database)
        let cluster  = Cluster(auth, system, database, disk)
        let disposer = Custodian .> apply(disk) .> apply(cluster)
        
        _Wait(h, 3 * tick, {(h)(
          db = database, d = disposer,
          auth, disk_dir, system, tick)
        =>
          // Read the old data, write some new data, then destroy it.
          db(_ExpectRespond(h, ":2\r\n"), ["GCOUNT"; "GET"; "foo"])
          db(_ExpectRespond(h, "+OK\r\n"), ["GCOUNT"; "INC"; "bar"; "3"])
          d.dispose()
          
          _Wait(h, 2 * tick, {(h)(auth, disk_dir, system, tick) =>
            // Create yet another database with the same disk directory.
            let database = Database(system)
            let disk     = DiskSetup(system) .> replay(database)
            let cluster  = Cluster(auth, system, database, disk)
            let disposer = Custodian .> apply(disk) .> apply(cluster)
            
            _Wait(h, 3 * tick, {(h)(db = database, d = disposer, disk_dir) =>
              // Read the both of the data items we persisted to disk.
              db(_ExpectRespond(h, ":2\r\n"), ["GCOUNT"; "GET"; "foo"])
              db(_ExpectRespond(h, ":3\r\n"), ["GCOUNT"; "GET"; "bar"])
              d.dispose()
              disk_dir.remove()
            })
          })
        })
      })
    })
