use crdt = "crdt"

interface val _SendDeltasFn
  fun apply(deltas: (String, crdt.Tokens box))
