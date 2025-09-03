##[
Helper module to handle paths.
]##

import std/strutils

proc headDir*(file: string): string =
  ##[
  Returns the very first directory from a string. If no directory is recognized, returns the string as is.

  It serves a specific use case in neostow, to collect an environment variable in the destination field and futurely expand it.
  ]##
  for i in file:
    if i == '/':
      break
    result = result & i
  return result

proc getchar*(s: string, c: char): string =
  ##[
  Consumes a given character from a given string, only at the first occurence

  It serves to consume the `$` symbol from environment variables.
  ]##
  result = newStringOfCap(s.len)
  var skipped = false
  for ch in s:
    if not skipped and ch == c:
      skipped = true
      continue
    result.add(ch)

proc basename*(path: string): string =
  ##[
  Returns the name of directory or filename, without the `/` separator.
  ]##
  var skipSep = 1
  if path.endsWith('/'):
    skipSep = 2
  for i in countdown(path.len - skipSep, 0):
    if path[i] == '/':
      return path[i + 1 .. ^skipSep]
  return path[0 .. ^skipSep]
