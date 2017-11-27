primitive Framing
  fun header_size(): USize =>
    ifdef ilp32 then compile_error "only 64-bit platforms are supported" end
    1 + 8
  
  fun write_header(size: USize): Array[U8] val =>
    [
      0x06 // magic byte
      (size >> (8 * 7)).u8()
      (size >> (8 * 6)).u8()
      (size >> (8 * 5)).u8()
      (size >> (8 * 4)).u8()
      (size >> (8 * 3)).u8()
      (size >> (8 * 2)).u8()
      (size >> (8 * 1)).u8()
      size.u8()
    ]
  
  fun parse_header(header: Array[U8] val): USize? =>
    if header(0)? != 0x06 then error end // magic byte
    (header(1)?.usize() << (8 * 7)) +
    (header(2)?.usize() << (8 * 6)) +
    (header(3)?.usize() << (8 * 5)) +
    (header(4)?.usize() << (8 * 4)) +
    (header(5)?.usize() << (8 * 3)) +
    (header(6)?.usize() << (8 * 2)) +
    (header(7)?.usize() << (8 * 1)) +
    (header(8)?.usize())
