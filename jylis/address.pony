class val Address is Equatable[Address val]
  let host: String
  let port: String
  let name: String
  
  new val create(host': String, port': String, name': String = "") =>
    (host, port, name) = (host', port', name')
  
  new val from_string(input: String) =>
    (host, port, name) =
      try
        let i = input.find(":")?.usize()
        try
          let j = input.find(":", (i + 1).isize())?.usize()
          (input.trim(0, i), input.trim(i + 1, j), input.trim(j + 1))
        else
          (input.trim(0, i), input.trim(i + 1), "")
        end
      else
        (input, "", "")
      end
  
  fun hash(): U64 => (0x2f * host.hash()) + (0x1f * port.hash()) + name.hash()
  
  fun eq(that: Address): Bool =>
    (host == that.host) and (port == that.port) and (name == that.name)
  
  fun string(): String iso^ =>
    recover
      String(host.size() + 1 + port.size() + 1 + name.size())
        .> append(host) .> push(':')
        .> append(port) .> push(':')
        .> append(name)
    end
