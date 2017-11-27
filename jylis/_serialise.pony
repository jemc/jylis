use "serialise"

class val _Serialise
  let _auth: AmbientAuth
  new val create(auth': AmbientAuth) => _auth = auth'
  
  fun tag signature(): Array[U8] val => Serialise.signature()
  
  fun to_bytes(obj: Any box): Array[U8] val? =>
    Serialised(SerialiseAuth(_auth), obj)?.output(OutputSerialisedAuth(_auth))
  
  fun from_bytes[A: Any #any](bytes: Array[U8] val): A? =>
    Serialised.input(InputSerialisedAuth(_auth), bytes)(DeserialiseAuth(_auth))?
    as A
