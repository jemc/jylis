class val Address is Equatable[Address val]
  let host: String
  let port: String
  let name: String
  
  new val create(host': String, port': String, name': String = "") =>
    (host, port, name) = (host', port', name')
  
  fun hash(): U64 => (0x2f * host.hash()) + (0x1f * port.hash()) + name.hash()
  
  fun eq(that: Address): Bool =>
    (host == that.host) and (port == that.port) and (name == that.name)
  
  fun string(): String =>
    recover
      String(host.size() + 1 + port.size() + 1 + name.size())
        .> append(host) .> push(':')
        .> append(port) .> push(':')
        .> append(name)
    end
