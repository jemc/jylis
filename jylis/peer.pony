use "crdt"

primitive PeerAddrHashFn
  fun hash(x: PeerAddr): U64 =>
    (0x2f * x._1.hash()) + (0x1f * x._2.hash()) + x._3.hash()
  
  fun eq(x: PeerAddr, y: PeerAddr): Bool =>
    (x._1 == y._1) and (x._2 == y._2) and (x._3 == y._3)

type PeerAddr is (String, String, String)

type PeerAddrP2Set is P2HashSet[PeerAddr, PeerAddrHashFn]

class Peer
  let addr: PeerAddr
  new create(addr': PeerAddr) =>
    (addr) = (addr')
