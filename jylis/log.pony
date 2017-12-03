use "logger"

type _StringableAny is (Stringable | _StringableVal)

interface box _StringableVal
  fun string(): String

class val Log
  let _log: Logger[String]
  new val create_fine(out: OutStream) => _log = StringLogger(Fine, out)
  new val create_info(out: OutStream) => _log = StringLogger(Info, out)
  new val create_warn(out: OutStream) => _log = StringLogger(Warn, out)
  new val create_err(out: OutStream) => _log = StringLogger(Error, out)
  
  fun fine(): Bool => _log(Fine)
  fun info(): Bool => _log(Info)
  fun warn(): Bool => _log(Warn)
  fun err(): Bool => _log(Error)
  
  fun apply(
    a: _StringableAny,
    b: _StringableAny = None,
    c: _StringableAny = None,
    d: _StringableAny = None)
    : Bool
  =>
    let out = recover trn String end
    out.append(a.string())
    if b isnt None then out.>push(';').>push(' ').append(b.string()) end
    if c isnt None then out.>push(';').>push(' ').append(c.string()) end
    if d isnt None then out.>push(';').>push(' ').append(d.string()) end
    _log.log(consume out)
    true
