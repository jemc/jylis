use "collections"
use "files"
use "glob"
use "resp"
use "inspect"

primitive DiskSetup
  fun apply(system: System): DiskAny =>
    // Return early if no disk_dir option was specified.
    let dir =
      try system.config.disk_dir as FilePath else
        system.log.info() and system.log.i("disk persistence is disabled")
        return DiskNone
      end
    
    // Try to create the directory.
    if not dir.mkdir() then
      system.log.err() and system.log.e(
        "disk dir couldn't be created at " + dir.path
      )
      system.dispose()
      return DiskNone
    end
    
    // Try to create a test file.
    with file =
      try CreateFile(FilePath(dir, "init.test.jylis")?) as File else
        system.log.err() and system.log.e(
          "disk test file couldn't be created in " + dir.path
        )
        system.dispose()
        return DiskNone
      end
    do
      // Try to write to the test file.
      if not file.print("OK") then
        system.log.err() and system.log.e(
          "disk test file couldn't be written at " + file.path.path
        )
        system.dispose()
        return DiskNone
      end
      
      // Try to delete the test file.
      if not file.path.remove() then
        system.log.err() and system.log.e(
          "disk test file couldn't be deleted at " + file.path.path
        )
        system.dispose()
        return DiskNone
      end
    end
    
    // Create the Disk actor and return it.
    system.log.info() and system.log.i(
      "disk persistence is enabled at " + dir.path
    )
    Disk(dir, system)

trait tag DiskAny
  be dispose()
  be replay(database: Database)
  be append_write(name: String, data: Array[U8] val)
  be append_writev(name: String, data: Array[ByteSeq] val)

primitive DiskNone is DiskAny
  fun tag dispose() => None
  fun tag replay(database: Database) => None
  fun tag append_write(name: String, data: Array[U8] val) => None
  fun tag append_writev(name: String, data: Array[ByteSeq] val) => None

actor Disk is DiskAny
  let _dir: FilePath
  let _system: System
  
  let _append_files: Map[String, File] = _append_files.create()
  
  new create(dir': FilePath, system': System) =>
    (_dir, _system) = (dir', system')
  
  be dispose() =>
    """
    Flush and close any file handles we have open.
    """
    // TODO: consider relying on File._final instead of having this method.
    for file in _append_files.values() do
      _flush(file)
      file.dispose()
    end
    _append_files.clear()
  
  be replay(database: Database) =>
    """
    Replay all append-only files in the directory into the given Database.
    """
    for path in Glob.glob(_dir, "append.*.jylis").values() do
      // Calculate size ahead of time in this actor, so that we're sure to get
      // an answer that doesn't change while this actor writes to that file.
      var size: USize = 0
      with file = File(path) do size = file.size() end
      
      DiskReplay(_system, database, path, size)
    end
  
  be append_write(name: String, data: Array[U8] val) =>
    """
    Write the given bytes to the append-only file with the given name.
    """
    let file = _append_file_for(name)
    file.queue(data)
    _maybe_flush(file)
  
  be append_writev(name: String, data: Array[ByteSeq] val) =>
    """
    Write the given I/O vector to the append-only file with the given name.
    """
    let file = _append_file_for(name)
    file.queuev(data)
    _maybe_flush(file)
  
  fun _flush(file: File) =>
    """
    Flush queued bytes to disk and run fsync on the file.
    """
    if not file.flush() then
      _system.log.err() and _system.log.e(
        "disk failed to flush file: " + file.path.path
      )
    end
    file.sync()
  
  // TODO: Either don't flush every time, or remove this function.
  fun ref _maybe_flush(file: File) => _flush(file)
  
  fun _file_path_for(name: String): FilePath =>
    try FilePath(_dir, name)?
    else _dir // unreachable, as long as the name doesn't include `..`
    end
  
  fun ref _append_file_for(name: String): File =>
    """
    Open an append-only file for the given name, seeking to the end of the file
    so we can start writing without overwriting existing data in the file.
    """
    try _append_files(name)? else
      let path = _file_path_for("append." + name + ".jylis")
      let file = File(path) .> seek_end(0)
      _append_files(name) = file
      file
    end

actor DiskReplay
  let _system: System
  let _database: Database
  let _name: String
  let _file: File
  let _size: USize
  let _errors: Array[String]
  let _parser: ResponseParser
  
  new create(
    system': System,
    database': Database,
    path': FilePath,
    size': USize)
  =>
    """
    Open the given file path on disk and read the given size number of bytes
    from it, deserializing those bytes as CRDT data into the given database.
    
    It is assumed that each file corresponds to one repo of the database, and
    that the files follow a naming convention of "append.REPO.jylis", where
    REPO is the name of the repo in the database to replay data into.
    
    The data will not be read all at once - it will be read in chunks,
    yielding back to the scheduler between each chunk to avoid taking
    too much time from other actors in the system. When the given number
    of bytes has been read, the actor will stop and be garbage-collected,
    after printing a final message.
    
    Note that we want to stop at the given number of bytes (indicating the
    total file size at the start of replay) instead of reading to the end of
    the file, because another actor may be adding more bytes to the file.
    We trust that the file is being written in an append-only way, so the
    bytes measured at the start of replay will remain unmodified for us to read.
    """
    (_system, _database, _size) = (system', database', size')
    _name = Path.base(path'.path, false).trim("append.".size())
    _file = File.open(path')
    _errors = []
    _parser = ResponseParser({ref(err)(e = _errors) => e.push(err) } ref)
    
    _system.log.debug() and _system.log.d(
      "disk replay starting for " + _name + " (size: " + _size.string() + ")"
    )
    _continue(0)
  
  be _continue(index: USize) =>
    // TODO: find optimal max read per behaviour size.
    let bytes: Array[U8] val = _file.read((_size - index).min(4096))
    if bytes.size() == 0 then _complete(); return end
    
    _system.log.debug() and _system.log.d(
      "disk replay for " + _name + ": " + Inspect(String.from_array(bytes))
    )
    
    _parser.append(bytes)
    // TODO: print an error when token parsing fails.
    
    try while true do
      let iter = _parser.next_tokens_iso()?
      let iter' = recover DatabaseCodecInIterator(consume iter) end
      // TODO: print an error when token deserialization fails.
      _database.converge_deltas(_name, consume iter')
    end end
    
    _continue(index + bytes.size())
  
  be _complete() =>
    _system.log.info() and _system.log.i("disk replay complete for " + _name)
