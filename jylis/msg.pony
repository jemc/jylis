trait box Msg
  fun string(): String

class box MsgAnnounceAddrs is Msg
  let my_addr: PeerAddr
  let known_addrs: PeerAddrP2Set
  fun string(): String => "AnnounceAddrs" // TODO: print data fields
  new box create(
    my_addr': PeerAddr,
    known_addrs': PeerAddrP2Set)
  =>
    my_addr = my_addr'
    known_addrs = known_addrs'

class box MsgRespondAddrs is Msg
  let known_addrs: PeerAddrP2Set
  fun string(): String => "RespondAddrs" // TODO: print data fields
  new box create(known_addrs': PeerAddrP2Set) => known_addrs = known_addrs'
