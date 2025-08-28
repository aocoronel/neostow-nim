proc headDir*(file: string): string =
  var count: int8
  for i in file:
    result = result & i
    if i == '/':
      count += 1
    if count == 2:
      break
  return result
