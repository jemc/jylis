use "time"

interface tag _HeartbeatableActor
  be _heartbeat()

class val Heart
  let _timers: Timers = Timers
  
  new val create(target: _HeartbeatableActor, interval: U64) =>
    let notify =
      object iso is TimerNotify
        fun apply(timer: Timer, count: U64): Bool =>
          target._heartbeat()
          true
      end
    
    _timers(Timer(consume notify, interval, interval))
  
  fun dispose() => _timers.dispose()
