use "files"

primitive DiskSetup
  fun apply(system: System, database: Database): DiskAny =>
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
      try CreateFile(FilePath(dir, "init.test.db.jylis")?) as File else
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
    Disk(dir)

trait tag DiskAny

primitive DiskNone is DiskAny

actor Disk is DiskAny
  let _dir: FilePath
  new create(dir': FilePath) => _dir = dir'
