use "collections"
use "format"
use "random"

class NameGenerator
  let _rand: Random
  
  let _adjectives: Array[String] = [
    "endless"
    "immense"
    "quiet"
    "resplendent"
    "supernal"
    "tranquil"
    "unimaginable"
    "willful"
  ]
  
  let _nouns: Array[String] = [
    "cloud"
    "forest"
    "mountain"
    "rainbow"
    "sea"
    "sky"
    "storm"
    "wilderness"
  ]
  
  new create(rand': Random) => _rand = rand'
  
  fun ref adjective(): String => _sample(_adjectives)
  fun ref noun(): String => _sample(_nouns)
  
  fun ref _sample(seq: ReadSeq[String]): String =>
    try seq(_rand.int[USize](seq.size()))? else "?" end
  
  fun ref hex(bytes: USize = 16): String =>
    let out = recover trn String end
    let fmt = FormatHexSmallBare
    for i in Range(0, bytes / 8) do
      out.append(Format.int[U64](_rand.u64(), fmt, PrefixDefault, 16))
    end
    for i in Range(0, bytes % 8) do
      out.append(Format.int[U8](_rand.u8(), fmt, PrefixDefault, 2))
    end
    consume out
  
  fun ref apply(): String =>
    // TODO: longer word lists, shorter hex
    adjective() + "-" + noun() + "-" + hex(14)
