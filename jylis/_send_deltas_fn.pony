use crdt = "crdt"

interface val _SendDeltasFn
  fun apply(name: String, delta: crdt.Tokens box)
