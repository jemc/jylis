use "ponytest"
use ".."

use "random"

class TestNameGenerator is UnitTest
  fun name(): String => "jylis.NameGenerator"
  
  fun apply(h: TestHelper) =>
    let n = NameGenerator(Rand)
    h.assert_eq[String](n(), "resplendent-cloud-b8815710055c557ba63ec56c2598")
    h.assert_eq[String](n(), "supernal-storm-2ae79eea1deef780515e87ae58aa")
    h.assert_eq[String](n(), "tranquil-mountain-b31de13717153693b3b6e6ca07d8")
