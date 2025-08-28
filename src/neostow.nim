import std/[symlinks, posix, os, strutils, paths, parseopt, asyncdispatch]

const MaxConcurrentOps = 10
var file: string
var check, verbose, overwrite, delete: bool
let proj_dir = paths.getCurrentDir()
var file_fallback = $proj_dir & ".neostow"

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

proc genSymlink(src: string, dest: string): Future[void] {.async.} =
  var src_path = proj_dir / Path(src)
  let src_file = extractFilename(src_path)

  var destSep: string = dest
  if not destSep.endsWith(DirSep):
    destSep.add(DirSep)

  destSep = destSep.replace("$HOME", getEnv("HOME"))

  destSep = expandTilde(destSep)

  var dest_path = Path(destSep.absolutePath)

  if delete:
    if symlinkExists(dest_path / src_file):
      removeFile($dest_path & $src_file)
      if verbose:
        echo "Deleted symlink: ", $dest_path & $src_file
    if not overwrite:
      return
  if symlinkExists(dest_path):
    if verbose:
      echo "Symlink already exists at ", dest_path
  else:
    if dirExists($src_path) or fileExists($src_path):
      try:
        createSymlink(src_path, dest_path / src_file)
        if verbose:
          echo "Created symlink: ", dest_path / src_file
      except OSError as e:
        echo "Failed to create symlink: ", e.msg
    else:
      echo "Source directory does not exist: ", src_path

proc readConfig(file: string): Future[void] {.async.} =
  var futures: seq[Future[void]] = @[]
  for line in lines(file):
    if line.len == 0 or line.startsWith("#"):
      continue
    let parts = line.split('=')
    if parts.len == 2:
      if check:
        continue
      let key = parts[0].strip
      let value = parts[1].strip
      futures.add genSymlink(key, value)
      if futures.len >= MaxConcurrentOps:
        await futures[0]
        futures.delete(0)
    else:
      if verbose:
        if check:
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
        check = true
        verbose = true
      file = p.key
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
        file = p.key
      of "delete", "d":
        delete = true
      of "overwrite", "o":
        delete = true
        overwrite = true
      of "verbose":
        verbose = true
      else:
        stderr.writeLine("Unknown option: ", p.key)
        quit(1)

  if not fileExists(file):
    if not fileExists(file_fallback):
      stderr.writeLine("Config file not found: " & file)
      quit(1)
    file = file_fallback

  if file.len == 0 or not fileExists(file):
    stderr.writeLine("No valid config file to load")
    quit(1)

  try:
    waitFor readConfig(file)
  except IOError:
    stderr.writeLine("Error opening file: " & file)
    quit(1)

when isMainModule:
  main()
