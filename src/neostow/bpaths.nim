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
