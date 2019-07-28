use "ponytest"
use ".."

use "random"

class TestNameGenerator is UnitTest
  fun name(): String => "jylis.NameGenerator"
  
  fun apply(h: TestHelper) =>
    let n = NameGenerator(Rand(99))
    h.assert_eq[String](n(), "trembling-flame-007863ec2d27")
    h.assert_eq[String](n(), "immersive-figure-487b4dc757bf")
    h.assert_eq[String](n(), "present-obelisk-9b01fa258e65")
    h.assert_eq[String](n(), "astral-pylon-43d01fec472e")
    h.assert_eq[String](n(), "nascent-banner-22f45352dfaf")
    h.assert_eq[String](n(), "apocryphal-effigy-7e9bc8f616f8")
    h.assert_eq[String](n(), "translucent-shape-2b6ba2e32ab6")
    h.assert_eq[String](n(), "endless-reward-32a82ba66e33")
