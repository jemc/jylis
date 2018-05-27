interface val _NameFn
  fun apply(name: String)

primitive _NameFnNone is _NameFn
  fun apply(name: String) => None
