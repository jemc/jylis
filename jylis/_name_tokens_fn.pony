use crdt = "crdt"

interface val _NameTokensFn
  fun apply(name: String, tokens: crdt.Tokens box)

primitive _NameTokensFnNone is _NameTokensFn
  fun apply(name: String, tokens: crdt.Tokens box) => None
