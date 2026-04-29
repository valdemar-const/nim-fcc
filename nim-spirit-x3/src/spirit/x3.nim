# spirit/x3.nim
import std/options
import std/strutils

# -- Абстрактный поток (итератор) ----------------------

type
  Stream* = ref object of RootObj   # базовый поток

# Виртуальные методы для работы с потоком
method next*(s: var Stream): Option[char] {.base.} = none(char)
method peek*(s: var Stream): Option[char] {.base.} = none(char)
method pos*(s: var Stream): int {.base.} = 0
method revert*(s: var Stream, p: int) {.base.} = discard

# -- Реализация строкового потока ----------------------

type
  StringStream = ref object of Stream
    data: string
    idx: int

method next*(s: var StringStream): Option[char] =
  if s.idx < s.data.len:
    result = some(s.data[s.idx])
    inc s.idx

method peek*(s: var StringStream): Option[char] =
  if s.idx < s.data.len: some(s.data[s.idx])
  else: none(char)

method pos*(s: var StringStream): int = s.idx
method revert*(s: var StringStream, p: int) = s.idx = p

proc newStringStream*(input: string): Stream =
  StringStream(data: input, idx: 0)

# -- Тип парсера ---------------------------------------

type
  Parser* = proc(s: var Stream): bool {.closure.}

# -- Базовые символьные парсеры ------------------------

let alpha*: Parser = proc(s: var Stream): bool =
  let c = peek(s)
  if c.isSome and c.get.isAlphaAscii:
    discard next(s)    # принимаем символ
    true
  else:
    false

let digit*: Parser = proc(s: var Stream): bool =
  let c = peek(s)
  if c.isSome and c.get.isDigit:
    discard next(s)
    true
  else:
    false

proc char*(c: char): Parser =
  result = proc(s: var Stream): bool =
    if peek(s) == some(c):
      discard next(s)
      true
    else:
      false

proc char*(cs: set[char]): Parser =
  result = proc(s: var Stream): bool =
    let c = peek(s)
    if c.isSome and c.get in cs:
      discard next(s)
      true
    else:
      false

proc literal*(s: string): Parser =
  ## Разбирает точную строку s, откатываясь при несовпадении.
  result = proc(stream: var Stream): bool =
    let saved = pos(stream)
    for c in s:
      if next(stream) != some(c):
        revert(stream, saved)
        return false
    return true

# -- Комбинаторы ----------------------------------------
proc `?`*(p: Parser): Parser =
  result = proc(s: var Stream): bool =
    let saved = pos(s)
    if not p(s):
      revert(s, saved)
    return true

proc `>>`*(p1, p2: Parser): Parser =
  result = proc(s: var Stream): bool =
    let saved = pos(s)
    if p1(s) and p2(s):
      return true
    revert(s, saved)
    false

proc `|`*(p1, p2: Parser): Parser =
  result = proc(s: var Stream): bool =
    let saved = pos(s)
    if p1(s):
      return true
    revert(s, saved)
    p2(s)

proc `*`*(p: Parser): Parser =
  result = proc(s: var Stream): bool =
    while true:
      let saved = pos(s)
      if not p(s):
        revert(s, saved)
        return true   # 0 вхождений — тоже успех

proc `+`*(p: Parser): Parser =
  result = proc(s: var Stream): bool =
    if not p(s):
      return false
    while true:
      let saved = pos(s)
      if not p(s):
        revert(s, saved)
        break
    return true

proc `%`*(p: Parser, sep: Parser): Parser =
  ?(p >> *(sep >> p))

proc get_space(): Parser;

proc token*(p: Parser, skip: Parser = get_space()): Parser =
  result = proc(s: var Stream): bool =
    let saved = pos(s)
    discard skip(s)          # пропускаем ведущие пробелы
    if p(s):                 # разбираем лексему
      discard skip(s)        # пропускаем хвостовые пробелы
      return true
    revert(s, saved)         # откат, если лексема не подошла
    false

# -- Запуск парсера -------------------------------------

proc parse*(p: Parser, stream: var Stream): bool =
  p(stream)

proc parse*(p: Parser, input: string): bool =
  var s = newStringStream(input)
  result = p(s) and (pos(s) == input.len)

proc phrase_parse*(p: Parser, skip: Parser, input: string): bool =
  var s = newStringStream(input)
  result = token(p, skip)(s) and pos(s) == input.len

# some default parsers

let space_char*: Parser = char({' ', '\t', '\n', '\r'})
let space*: Parser = *(space_char)

proc get_space(): Parser = space
