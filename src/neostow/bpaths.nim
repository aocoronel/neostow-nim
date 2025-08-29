import std/strutils

proc headDir*(file: string): string =
  for i in file:
    if i == '/':
      break
    result = result & i
  return result

proc getchar*(s: string, c: char): string =
  for i in 0..<s.len:
    if s[i] == c:
      return s[0..<i] & s[i+1..^1]
  return s

proc basename*(path: string): string =
  var skipSep = 1
  if path.endsWith('/'):
    skipSep = 2
  for i in countdown(path.len - skipSep, 0):
    if path[i] == '/':
      return path[i+1 .. ^skipSep]
  return path[0 .. ^skipSep]
