use crdt = "crdt"
use "resp" // TODO: fix ponyc and remove this line
use resp = "resp"

primitive DatabaseCodecOut
  fun apply(iter: crdt.TokensIterator): Array[ByteSeq] val =>
    let out: ResponseWriter = ResponseWriter
    into(out, iter)
    out.buffer.done()
  
  fun into(out: ResponseWriter, iter: crdt.TokensIterator) =>
    try
      while true do
        match iter.next[Any val]()?
        | let x: USize   => out.array_start(x)
        | let x: Float   => out.f64(x.f64())
        | let x: Number  => out.i64(x.i64())
        | let x: Bool    => out.i64(if x then 1 else 0 end)
        | let x: String  => out.string(x)
        | let x: Address =>
          out.array_start(3)
          out.string(x.host)
          out.string(x.port)
          out.string(x.name)
        else
          out.err("BADTOKEN - unknown CRDT token")
        end
      end
    end

primitive DatabaseCodecIn
  fun apply(input: Array[ByteSeq] val): DatabaseCodecInIterator iso^ =>
    recover
      let iter =
        try
          let errors = Array[String]
          let parser = ResponseParser({ref(err) => errors.push(err) } ref)
          for bytes in input.values() do
            parser.append(bytes)
            if errors.size() > 0 then error end
          end
          parser.next_tokens()?
        else
          Array[DataToken].values()
        end
      DatabaseCodecInIterator(iter)
    end

class DatabaseCodecInIterator is crdt.TokensIterator
  let _iter: Iterator[resp.DataToken]
  new create(iter': Iterator[resp.DataToken]) => _iter = iter'
  fun ref next[A: Any val](): A? =>
    var out: (A | None) = None // TODO: fix ponyc, leave out useless variable
    iftype A <: USize val                 then out = _iter.next()? as USize
    elseif A <: (Float val & Real[A] val) then out = A.from[F64]((_iter.next()? as String).f64())
    elseif A <: (Int val & Real[A] val)   then out = A.from[I64](_iter.next()? as I64)
    elseif A <: Bool val                  then out = (_iter.next()? as I64) != 0
    elseif A <: String val                then out = _iter.next()? as String
    elseif A <: Address val               then
      if (_iter.next()? as USize) != 3 then error end
      out = Address(
        (_iter.next()? as String),
        (_iter.next()? as String),
        (_iter.next()? as String)
      )
    else error
    end
    out as A
