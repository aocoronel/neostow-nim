import std/[symlinks, posix, os, strutils, paths, parseopt, asyncdispatch, envvars]
import neostow/paths

const MaxConcurrentOps: int8 = 10

var
  gConfigFile: string
  gCheckCmd, gVerboseFlag, gOverwriteFlag, gDeleteFlag: bool
  gProjectDir: Path
  gConfigFileFallback: string

proc writeVersion() =
  echo "v1.0.0"

proc writeHelp() =
  echo """The declarative GNU Stow

  Usage: neostow [OPTION] [COMMAND] [FILE]

  Options:
    --verbose            Enable verbose
    -d, --delete         Remove all symlinks
    -h, --help           Displays this message and exits
    -o, --overwrite      Overwrite symlinks
    -v                   Display version

  Commands:
    check                Check for inconsistencies in config file
  """

proc genSymlink(src, dest: Path, src_file: Path): Future[void] {.async.} =
  if gDeleteFlag:
    if symlinkExists(dest / src_file):
      removeFile($dest & $src_file)
      if gVerboseFlag:
        echo "Deleted symlink: ", $dest & $src_file
    if not gOverwriteFlag:
      return
  if symlinkExists(dest):
    if gVerboseFlag:
      echo "Symlink already exists at ", dest
  else:
    if dirExists($src) or fileExists($src):
      try:
        createSymlink(src, dest / src_file)
        if gVerboseFlag:
          echo "Created symlink: ", dest / src_file
      except OSError as e:
        echo "Failed to create symlink: ", e.msg
    else:
      echo "Source directory does not exist: ", src

proc stabilizeDestination(dest: string): Path =
  var destination = getchar(dest, '$')

  var dest_env = headDir(destination)
  if not destination.endsWith(DirSep):
    destination.add(DirSep)
  if envvars.existsEnv(dest_env):
    destination = destination.replace(dest_env, getEnv(dest_env))

  destination = expandTilde(destination)

  Path(destination)

proc readConfig(file: string): Future[void] {.async.} =
  var futures: seq[Future[void]] = @[]
  for line in lines(file):
    if line.len == 0 or line.startsWith("#"):
      continue
    let parts = line.split('=')
    if parts.len == 2:
      if gCheckCmd:
        continue
      var src_file: string
      let
        src = parts[0].strip
        tmp_dest = parts[1].strip
        dest = stabilizeDestination(tmp_dest)
        src_isdir = dirExists(src)
      if src_isdir:
        src_file = parentDir(src)
      else:
        src_file = extractFilename(src)
      var src_path = absolutePath(gProjectDir) / Path(src)
      futures.add genSymlink(src_path, dest, Path(src_file))
      if futures.len >= MaxConcurrentOps:
        await futures[0]
        futures.delete(0)
    else:
      if gVerboseFlag:
        if gCheckCmd:
          echo "Found malformed element at line: ", line.len
        else:
          echo "Skipping malformed element: line ", line.len

  await all(futures)

proc main() =
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdArgument:
      case p.key
      of "check":
        gCheckCmd = true
        gVerboseFlag = true
      gConfigFile = p.key
      if fileExists(gConfigFile):
        gProjectDir = parentDir(Path(gConfigFile))
      else:
        gProjectDir = paths.getCurrentDir()
    of cmdLongOption, cmdShortOption:
      case p.key
      of "help", "h":
        writeHelp()
        quit(0)
      of "version", "v":
        writeVersion()
        quit(0)
      of "f":
        p.next()
        if p.kind != cmdArgument:
          stderr.writeLine("Error: -f requires an argument")
          quit(1)
        gConfigFile = p.key
      of "delete", "d":
        gDeleteFlag = true
      of "overwrite", "o":
        gDeleteFlag = true
        gOverwriteFlag = true
      of "verbose":
        gVerboseFlag = true
      else:
        stderr.writeLine("Unknown option: ", p.key)
        quit(1)

  if not fileExists(gConfigFile):
    gConfigFileFallback = $gProjectDir & ".neostow"
    if not fileExists(gConfigFileFallback):
      stderr.writeLine("Config file not found: " & gConfigFile)
      quit(1)
    gConfigFile = gConfigFileFallback

  if gConfigFile.len == 0 or not fileExists(gConfigFile):
    stderr.writeLine("No valid config file to load")
    quit(1)

  try:
    waitFor readConfig(gConfigFile)
  except IOError:
    stderr.writeLine("Error opening file: " & gConfigFile)
    quit(1)

when isMainModule:
  main()
