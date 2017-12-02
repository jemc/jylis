use "ponytest"
use ".."

class TestAddress is UnitTest
  fun name(): String => "jylis.Address"
  
  fun apply(h: TestHelper) =>
    let addr = Address("127.0.0.1", "19999", "alpha")
    h.assert_eq[String](addr.string(), "127.0.0.1:19999:alpha")
    
    h.assert_eq[Address](
      Address("127.0.0.1", "19999", "alpha"),
      Address.from_string("127.0.0.1:19999:alpha"))
    
    h.assert_eq[Address](
      Address("127.0.0.1", "19999", ""),
      Address.from_string("127.0.0.1:19999:"))
    
    h.assert_eq[Address](
      Address("127.0.0.1", "", "alpha"),
      Address.from_string("127.0.0.1::alpha"))
    
    h.assert_eq[Address](
      Address("", "", ""),
      Address.from_string(""))
    
    h.assert_eq[Address](
      Address("", "", "::"),
      Address.from_string("::::"))
