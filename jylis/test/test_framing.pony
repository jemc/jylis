use "ponytest"
use ".."

class TestFraming is UnitTest
  fun name(): String => "jylis.Framing"
  
  fun apply(h: TestHelper)? =>
    let golden_inverse = 2 / (1 + F64(5).sqrt()) // nice irrational number
    let size = golden_inverse.bits().usize()
    
    let header = Framing.write_header(size)
    h.assert_eq[USize](Framing.header_size(), header.size())
    h.assert_eq[USize](size, Framing.parse_header(header)?)
    
    try
      let bad_header = recover val header.clone().>update(0, 0xFF)? end
      try Framing.parse_header(bad_header)?
        h.fail("expected tampering with first byte to break the header")
      end
    else h.fail("failed to tamper with first byte of header")
    end
