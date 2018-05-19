use "collections"
use "files"

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
  be append_write(name: String, data: Array[U8] val)
  be append_writev(name: String, data: Array[ByteSeq] val)

primitive DiskNone is DiskAny
  fun tag dispose() => None
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
    try _append_files(name)? else
      let file = File(_file_path_for("append." + name + ".jylis"))
      _append_files(name) = file
      file
    end
