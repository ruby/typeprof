## update
def foo(flag)
  h = {}
  h[:a] = 1 if flag
  h[:b] = 2 if flag
  h[:c] = 3 if flag
  h[:d] = 4 if flag
  h[:e] = 5 if flag
  h[:f] = 6 if flag
  h[:g] = 7 if flag
  h[:h] = 8 if flag
  h[:i] = 9 if flag
  h[:j] = 10 if flag
  h[:k] = 11 if flag
  h[:l] = 12 if flag
  h[:m] = 13 if flag
  h[:n] = 14 if flag
  h[:o] = 15 if flag
  h
end

## assert
class Object
  def foo: (untyped) -> ({  } | { a: Integer } | { a: Integer, b: Integer } | { a: Integer, b: Integer, c: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer, h: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer, h: Integer, i: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer, h: Integer, i: Integer, j: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer, h: Integer, i: Integer, j: Integer, k: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer, h: Integer, i: Integer, j: Integer, k: Integer, l: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer, h: Integer, i: Integer, j: Integer, k: Integer, l: Integer, m: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer, h: Integer, i: Integer, j: Integer, k: Integer, l: Integer, m: Integer, n: Integer } | { a: Integer, b: Integer, c: Integer, d: Integer, e: Integer, f: Integer, g: Integer, h: Integer, i: Integer, j: Integer, k: Integer, l: Integer, m: Integer, n: Integer, o: Integer })
end
