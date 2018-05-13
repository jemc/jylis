use "crdt"

trait val Msg
  fun string(): String

class val MsgPong is Msg
  new box create() => None
  fun string(): String => "Pong"

class val MsgExchangeAddrs is Msg
  let known_addrs: P2Set[Address]
  new box create(known_addrs': P2Set[Address]) => known_addrs = known_addrs'
  fun string(): String => "ExchangeAddrs" // TODO: print data fields

class val MsgAnnounceAddrs is Msg
  let known_addrs: P2Set[Address]
  new box create(known_addrs': P2Set[Address]) => known_addrs = known_addrs'
  fun string(): String => "AnnounceAddrs" // TODO: print data fields

class val MsgPushDeltas is Msg
  let deltas: (String, Array[ByteSeq] box)
  new box create(deltas': (String, Array[ByteSeq] box)) =>
    deltas = deltas'
  fun string(): String => "PushDeltas" // TODO: print data fields?
