use "ponytest"
use ".."

use "random"

class TestNameGenerator is UnitTest
  fun name(): String => "jylis.NameGenerator"
  
  fun apply(h: TestHelper) =>
    let n = NameGenerator(Rand(100))
    h.assert_eq[String](n(), "comforting-rune-00996429bdc4")
    h.assert_eq[String](n(), "momentary-lake-60d77f9ee067")
    h.assert_eq[String](n(), "prosaic-amber-b74e01de1031")
    h.assert_eq[String](n(), "fine-omen-8fe065d4f648")
    h.assert_eq[String](n(), "transparent-challenge-655f1573c7ac")
    h.assert_eq[String](n(), "idle-gem-2bdbb7353167")
    h.assert_eq[String](n(), "commendable-thread-f4b5fb63ad55")
    h.assert_eq[String](n(), "incoherent-soul-393a3745471c")
