use "resp"
use "crdt"
use "inspect"

trait val MsgAny
  fun name(): String

primitive Msg
  fun from_wire(
    iter: DatabaseCodecInIterator iso)
    : (MsgAny, DatabaseCodecInIterator iso^)?
  =>
    if iter.next[USize]()? != 2 then error end
    let msg =
      match iter.next[String]()?
      | MsgPong.name()          => MsgPong
      | MsgExchangeAddrs.name() => MsgExchangeAddrs
      | MsgAnnounceAddrs.name() => MsgAnnounceAddrs
      | MsgPushDeltas.name()    => MsgPushDeltas
      else error
      end
    (msg, consume iter)
  
  fun _to_wire(msg: MsgAny, resp: ResponseWriter) =>
    resp.array_start(2)
    resp.string(msg.name())
    // Assume the message itself will come next after this function is called.

primitive MsgPong is MsgAny
  fun name(): String => "PONG"
  
  fun from_wire(iter: DatabaseCodecInIterator iso)? =>
    if iter.next[USize]()? != 0 then error end
  
  fun to_wire(): Array[ByteSeq] val =>
    let resp: ResponseWriter = ResponseWriter
    Msg._to_wire(this, resp)
    resp.array_start(0)
    resp.buffer.done()

primitive MsgExchangeAddrs is MsgAny
  fun name(): String => "XCHG"
  
  fun from_wire(iter: DatabaseCodecInIterator iso): P2Set[Address]? =>
    P2Set[Address] .> from_tokens(consume iter)?
  
  fun to_wire(known_addrs: P2Set[Address]): Array[ByteSeq] val =>
    let resp: ResponseWriter = ResponseWriter
    let tokens = Tokens .> from(known_addrs)
    Msg._to_wire(this, resp)
    DatabaseCodecOut.into(resp, tokens.iterator())
    resp.buffer.done()

primitive MsgAnnounceAddrs is MsgAny
  fun name(): String => "ANNC"
  
  fun from_wire(iter: DatabaseCodecInIterator iso): P2Set[Address]? =>
    P2Set[Address] .> from_tokens(consume iter)?
  
  fun to_wire(known_addrs: P2Set[Address]): Array[ByteSeq] val =>
    let resp: ResponseWriter = ResponseWriter
    let tokens = Tokens .> from(known_addrs)
    Msg._to_wire(this, resp)
    DatabaseCodecOut.into(resp, tokens.iterator())
    resp.buffer.done()

primitive MsgPushDeltas is MsgAny
  fun name(): String => "PDLT"
  
  fun from_wire(
    iter: DatabaseCodecInIterator iso)
    : (String, DatabaseCodecInIterator iso^)?
  =>
    if iter.next[USize]()? != 2 then error end
    let name' = iter.next[String]()?
    (name', consume iter)
  
  fun to_wire(name': String): Array[ByteSeq] iso^ =>
    let resp: ResponseWriter = ResponseWriter
    Msg._to_wire(this, resp)
    resp.array_start(2)
    resp.string(name')
    // Expect the actual deltas to be encoded next and appended into the array.
    resp.buffer.done()
