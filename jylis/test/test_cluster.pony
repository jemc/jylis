use "ponytest"
use ".."

class TestCluster is UnitTest
  fun name(): String => "jylis.Cluster"
  
  fun apply(h: TestHelper)? =>
    h.long_test(5_000_000_000)
    
    let auth = h.env.root as AmbientAuth
    let log  = Log.create_fine(h.env.out)
    
    let foo = Address("127.0.0.1", "9999", "foo")
    let bar = Address("127.0.0.1", "9998", "bar")
    let baz = Address("127.0.0.1", "9997", "baz")
    
    let foo_s = Server(auth, log, foo, "9999")
    let bar_s = Server(auth, log, bar, "9998")
    let baz_s = Server(auth, log, baz, "9997")
    
    h.dispose_when_done(foo_s)
    h.dispose_when_done(bar_s)
    h.dispose_when_done(baz_s)
    
    let foo_c = Cluster(auth, log, foo, [], foo_s)
    let bar_c = Cluster(auth, log, bar, [foo], bar_s)
    let baz_c = Cluster(auth, log, baz, [foo], baz_s)
    
    h.dispose_when_done(foo_c)
    h.dispose_when_done(bar_c)
    h.dispose_when_done(baz_c)
    
    h.complete(true)
