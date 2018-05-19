use "ponytest"
use "time"

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
