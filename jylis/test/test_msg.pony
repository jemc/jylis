use "ponytest"
use ".."
use "crdt"
use buffered = "buffered"

class TestMsg is UnitTest
  fun name(): String => "jylis.Msg"
  
  fun _from_wire(
    data: Array[ByteSeq] val)
    : (MsgAny, DatabaseCodecInIterator iso^)?
  =>
    Msg.from_wire(DatabaseCodecIn(data))?
  
  fun apply(h: TestHelper) =>
    try
      (let msg, let iter) = _from_wire(MsgPong.to_wire())?
      h.assert_eq[String](MsgPong.name(), msg.name())
      h.assert_eq[None](MsgPong.from_wire(consume iter)?, None)
    else
      h.assert_no_error({()? => error }, "MsgPong")
    end
    
    try
      let addrs = P2Set[Address] .> set(Address("a", "b", "c"))
      (let msg, let iter) = _from_wire(MsgExchangeAddrs.to_wire(addrs))?
      h.assert_eq[String](MsgExchangeAddrs.name(), msg.name())
      let addrs' = MsgExchangeAddrs.from_wire(consume iter)?
      h.assert_eq[P2Set[Address]](addrs, addrs')
    else
      h.assert_no_error({()? => error }, "MsgExchangeAddrs")
    end
    
    try
      let addrs = P2Set[Address] .> set(Address("a", "b", "c"))
      (let msg, let iter) = _from_wire(MsgAnnounceAddrs.to_wire(addrs))?
      h.assert_eq[String](MsgAnnounceAddrs.name(), msg.name())
      let addrs' = MsgAnnounceAddrs.from_wire(consume iter)?
      h.assert_eq[P2Set[Address]](addrs, addrs')
    else
      h.assert_no_error({()? => error }, "MsgAnnounceAddrs")
    end
