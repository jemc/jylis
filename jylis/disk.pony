use "files"

trait val DiskAny
  fun setup(log: Log)?

primitive DiskNone is DiskAny
  fun setup(log: Log) =>
    log.info() and log.i("disk persistence is disabled")

class val Disk is DiskAny
  let _dir: FilePath
  
  new val create(dir': FilePath) => _dir = dir'
  
  fun setup(log: Log)? =>
    // Try to create the directory.
    if not _dir.mkdir() then
      log.err() and log.e("disk dir couldn't be created at " + _dir.path)
      error
    end
    
    let file =
      try CreateFile(FilePath(_dir, "init.test.db.jylis")?) as File else
        log.err() and log.e(
          "disk test file couldn't be created in " + _dir.path
        )
        error
      end
    
    file.queue("OK\n")
    
    if not file.flush() then
      log.err() and log.e(
        "disk test file couldn't be written at " + file.path.path
      )
      error
    end
    
    log.info() and log.i("disk persistence is enabled at " + _dir.path)
