use "ponytest"
use ".."

use "random"

class TestNameGenerator is UnitTest
  fun name(): String => "jylis.NameGenerator"
  
  fun apply(h: TestHelper) =>
    let n = NameGenerator(Rand(100))
    h.assert_eq[String](n(), "manifold-fable-320332505658")
    h.assert_eq[String](n(), "legendary-orbit-b3eefbc45bee")
    h.assert_eq[String](n(), "whistling-energy-68572cf79300")
    h.assert_eq[String](n(), "occluded-music-4ea96b7a99ab")
    h.assert_eq[String](n(), "lucent-firmament-fe1f7b797319")
    h.assert_eq[String](n(), "natal-certainty-027e6ae3785e")
    h.assert_eq[String](n(), "blessed-request-c87663a105bd")
    h.assert_eq[String](n(), "sentimental-order-a670630f07b7")
