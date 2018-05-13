use crdt = "crdt"
use "resp" // TODO: fix ponyc and remove this line
use resp = "resp"

primitive DatabaseCodecOut
  fun apply(out: Respond, iter: crdt.TokensIterator) =>
    try
      while true do
        match iter.next[Any val]()?
        | let x: USize  => out.array_start(x)
        | let x: Float  => out.f64(x.f64())
        | let x: Number => out.i64(x.i64())
        | let x: Bool   => out.i64(if x then 1 else 0 end)
        | let x: String => out.string(x)
        else               out.err("BADTOKEN - unknown CRDT token")
        end
      end
    end

class DatabaseCodecInIterator is crdt.TokensIterator
  let _iter: Iterator[resp.DataToken]
  new create(iter': Iterator[resp.DataToken]) => _iter = iter'
  fun ref next[A: Any val](): A? =>
    var out: (A | None) = None // TODO: fix ponyc, leave out useless variable
    iftype A <: USize                 then out = _iter.next()? as USize
    elseif A <: (Float & Real[A] val) then out = A.from[F64]((_iter.next()? as String).f64())
    elseif A <: (Int & Real[A] val)   then out = A.from[I64](_iter.next()? as I64)
    elseif A <: Bool                  then out = (_iter.next()? as I64) != 0
    elseif A <: String                then out = _iter.next()? as String
    else error
    end
    out as A
