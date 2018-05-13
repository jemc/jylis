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
  fun apply(h: TestHelper, duration: F64, fn: {(TestHelper)} val) =>
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
    
    timers(Timer(consume notify, (duration * 1_000_000_000).u64()))

class TestCluster is UnitTest
  fun name(): String => "jylis.Cluster"
  
  fun _tick(): F64 => 0.050 // 50ms
  
  fun _addr(string: String): Address =>
    Address.from_string("127.0.0.1:" + string)
  
  fun _new_system(
    h: TestHelper,
    port: String,
    addr: Address,
    seed_addrs: Array[Address] iso = [])
    : System
  =>
    let config = Config
    config.port           = port
    config.addr           = addr
    config.seed_addrs     = consume seed_addrs
    config.heartbeat_time = _tick()
    config.log            = Log.create_err(h.env.out)
    System(consume config)
  
  fun apply(h: TestHelper)? =>
    h.long_test((10 * _tick() * 1_000_000_000).u64())
    let auth = h.env.root as AmbientAuth
    
    let foo = _new_system(h, "6379", _addr("9999:foo"))
    let bar = _new_system(h, "6378", _addr("9998:bar"), [_addr("9999")])
    let baz = _new_system(h, "6377", _addr("9997:baz"), [_addr("9999")])
    
    let foo_d = Database(foo)
    let bar_d = Database(bar)
    let baz_d = Database(baz)
    
    let foo_s = Server(auth, foo, foo_d)
    let bar_s = Server(auth, bar, bar_d)
    let baz_s = Server(auth, baz, baz_d)
    
    h.dispose_when_done(foo_s)
    h.dispose_when_done(bar_s)
    h.dispose_when_done(baz_s)
    
    let foo_c = Cluster(auth, foo, foo_d)
    let bar_c = Cluster(auth, bar, bar_d)
    let baz_c = Cluster(auth, baz, baz_d)
    
    h.dispose_when_done(foo_c)
    h.dispose_when_done(bar_c)
    h.dispose_when_done(baz_c)
    
    let tick = _tick()
    _Wait(h, 3 * tick, {(h)(foo_d, bar_d, baz_d, tick) =>
      foo_d(_ExpectRespond(h, "+OK\r\n"), ["GCOUNT"; "INC"; "foo"; "2"])
      bar_d(_ExpectRespond(h, "+OK\r\n"), ["GCOUNT"; "INC"; "foo"; "3"])
      baz_d(_ExpectRespond(h, "+OK\r\n"), ["GCOUNT"; "INC"; "foo"; "4"])
      
      _Wait(h, 2 * tick, {(h) =>
        foo_d(_ExpectRespond(h, ":9\r\n"), ["GCOUNT"; "GET"; "foo"])
      })
    })
