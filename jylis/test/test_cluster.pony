use "ponytest"
use "logger"
use ".."

class TestCluster is UnitTest
  fun name(): String => "jylis.Cluster"
  
  fun apply(h: TestHelper)? =>
    h.long_test(5_000_000_000)
    
    let log = StringLogger(Fine, h.env.out)
    
    let foo = Address("127.0.0.1", "9999", "foo")
    let bar = Address("127.0.0.1", "9998", "bar")
    
    let foo_c = Cluster(h.env.root as AmbientAuth, log, foo, [])
    let bar_c = Cluster(h.env.root as AmbientAuth, log, bar, [foo])
    
    h.dispose_when_done(foo_c)
    h.dispose_when_done(bar_c)
