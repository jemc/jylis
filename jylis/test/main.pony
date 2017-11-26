use "ponytest"
use ".."

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  
  fun tag tests(test: PonyTest) =>
    test(TestPeer)
