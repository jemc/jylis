use "ponytest"
use ".."

class TestPeer is UnitTest
  fun name(): String => "jylis.Peer"
  
  fun apply(h: TestHelper) =>
    h.long_test(5_000_000_000)
    
    Peer
    
    h.complete(true)
