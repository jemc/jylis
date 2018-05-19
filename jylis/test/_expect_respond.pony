use "ponytest"
use "resp"

primitive _ExpectRespond
  fun apply(h: TestHelper, expected: String): Respond =>
    let action = (digestof this).string() + ": " + expected
    h.expect_action(action)
    Respond(_ExpectRespondTo(h, expected, action))

actor _ExpectRespondTo
  let _h: TestHelper
  let _action: String
  let _expected: String
  var _actual: String ref = String
  
  new create(h: TestHelper, expected: String, action: String) =>
    (_h, _expected, _action) = (h, expected, action)
  
  be write(data: ByteSeq) =>
    _capture(data)
    _h.log(_actual.clone())
    _maybe_finish()
  
  be writev(data: ByteSeqIter) =>
    for d in data.values() do _capture(d) end
    _h.log(_actual.clone())
    _maybe_finish()
  
  fun ref _capture(data': ByteSeq) =>
    match data'
    | let data: String        => _actual.append(data)
    | let data: Array[U8] val => _actual.concat(data.values())
    end
  
  fun _maybe_finish() =>
    if _actual.size() >= _expected.size() then
      _h.assert_eq[String](_actual.clone(), _expected)
      _h.complete_action(_action)
    end
