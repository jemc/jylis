use "crdt"

trait box Msg
  fun string(): String

class box MsgAnnounceAddrs is Msg
  let known_addrs: P2Set[Address]
  new box create(known_addrs': P2Set[Address]) => known_addrs = known_addrs'
  fun string(): String => "AnnounceAddrs" // TODO: print data fields

class box MsgRespondAddrs is Msg
  let known_addrs: P2Set[Address]
  new box create(known_addrs': P2Set[Address]) => known_addrs = known_addrs'
  fun string(): String => "RespondAddrs" // TODO: print data fields
