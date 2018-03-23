use "ponytest"
use "time"
use "resp"
use ".."

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

primitive _Wait
  """
  A quick and dirty Timers wrapper that lets you pass a lambda to execute later
  in a test, passing the TestHelper along to the lambda on the other side.
  """
  fun apply(h: TestHelper, duration: U64, fn: {(TestHelper)} val) =>
    let timers: Timers = Timers
    h.dispose_when_done(timers)
    
    let action = (digestof timers).string() + " wait " + duration.string()
    h.expect_action(action)
    
    let notify =
      object iso is TimerNotify
        let _h: TestHelper = h
        let _fn: {(TestHelper)} val = fn
        fun apply(timer: Timer, count: U64): Bool =>
          _fn(_h)
          _h.complete_action(action)
          true
      end
    
    timers(Timer(consume notify, duration))

class TestCluster is UnitTest
  fun name(): String => "jylis.Cluster"
  
  fun apply(h: TestHelper)? =>
    let tick = 50_000_000 // 50ms
    h.long_test(10 * tick)
    
    let auth = h.env.root as AmbientAuth
    let log  = Log.create_err(h.env.out)
    
    let foo = Address("127.0.0.1", "9999", "foo")
    let bar = Address("127.0.0.1", "9998", "bar")
    let baz = Address("127.0.0.1", "9997", "baz")
    
    let foo_s = Server(auth, log, foo, "6379")
    let bar_s = Server(auth, log, bar, "6378")
    let baz_s = Server(auth, log, baz, "6377")
    
    h.dispose_when_done(foo_s)
    h.dispose_when_done(bar_s)
    h.dispose_when_done(baz_s)
    
    let foo_c = Cluster(auth, log, foo, [], foo_s, tick)
    let bar_c = Cluster(auth, log, bar, [foo], bar_s, tick)
    let baz_c = Cluster(auth, log, baz, [foo], baz_s, tick)
    
    h.dispose_when_done(foo_c)
    h.dispose_when_done(bar_c)
    h.dispose_when_done(baz_c)
    
    _Wait(h, 3 * tick, {(h)(foo_s, bar_s, baz_s) =>
      foo_s(_ExpectRespond(h, "+OK\r\n"), ["GCOUNT"; "INC"; "foo"; "2"])
      bar_s(_ExpectRespond(h, "+OK\r\n"), ["GCOUNT"; "INC"; "foo"; "3"])
      baz_s(_ExpectRespond(h, "+OK\r\n"), ["GCOUNT"; "INC"; "foo"; "4"])
      
      _Wait(h, 2 * tick, {(h) =>
        foo_s(_ExpectRespond(h, ":9\r\n"), ["GCOUNT"; "GET"; "foo"])
      })
    })
