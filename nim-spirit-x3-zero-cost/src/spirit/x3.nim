# spirit/x3.nim
import std/options
import std/strutils

# ── Sentinel «атрибут не нужен» ─────────────────────────────────────────────
type Void* = object

# ── Контекст разбора ────────────────────────────────────────────────────────
type
  ParseContext* = object
    input*: string
    pos*:   int

proc peek*(ctx: ParseContext): Option[char] {.inline.} =
  if ctx.pos < ctx.input.len: some(ctx.input[ctx.pos])
  else: none(char)

proc advance*(ctx: var ParseContext) {.inline.} = inc ctx.pos
proc save*(ctx: ParseContext): int {.inline.} = ctx.pos
proc restore*(ctx: var ParseContext, p: int) {.inline.} = ctx.pos = p

# ── Тип парсера ─────────────────────────────────────────────────────────────
type
  Parser*[A] = object
    fn*: proc(ctx: var ParseContext, attr: var A): bool {.closure.}

# ── Запуск ──────────────────────────────────────────────────────────────────
proc parse*[A](p: Parser[A], input: string, attr: var A): bool =
  var ctx = ParseContext(input: input, pos: 0)
  p.fn(ctx, attr) and ctx.pos == input.len

proc parse*[A](p: Parser[A], input: string): bool =
  var attr: A
  var ctx = ParseContext(input: input, pos: 0)
  p.fn(ctx, attr) and ctx.pos == input.len

# ── Утилиты ─────────────────────────────────────────────────────────────────

## Превращает Parser[A] в Parser[Void] — атрибут игнорируется
proc omit*[A](p: Parser[A]): Parser[Void] =
  Parser[Void](fn: proc(ctx: var ParseContext, attr: var Void): bool =
    var dummy: A
    p.fn(ctx, dummy)
  )

## Помечает парсер как «сохранять атрибут» (явно, против omit)
proc capture*[A](p: Parser[A]): Parser[A] = p

# ── Базовые парсеры ──────────────────────────���──────────────────────────────
proc satisfy*(pred: proc(c: char): bool {.closure.}): Parser[char] =
  Parser[char](fn: proc(ctx: var ParseContext, attr: var char): bool =
    let c = peek(ctx)
    if c.isSome and pred(c.get):
      attr = c.get
      advance(ctx)
      true
    else: false
  )

let alpha*: Parser[char] =
  satisfy(proc(c: char): bool = isAlphaAscii(c))

let digit*: Parser[char] =
  satisfy(proc(c: char): bool = isDigit(c))

let anyChar*: Parser[char] =
  satisfy(proc(c: char): bool = true)

proc ch*(c: char): Parser[char] =
  satisfy(proc(x: char): bool = x == c)

proc ch*(cs: set[char]): Parser[char] =
  satisfy(proc(x: char): bool = x in cs)

## literal → Parser[Void]: ключевые слова нам как атрибут не нужны
proc literal*(s: string): Parser[Void] =
  Parser[Void](fn: proc(ctx: var ParseContext, attr: var Void): bool =
    let saved = save(ctx)
    for c in s:
      let got = peek(ctx)
      if got.isNone or got.get != c:
        restore(ctx, saved)
        return false
      advance(ctx)
    true
  )

## lit → Parser[string]: когда значение нужно
proc lit*(s: string): Parser[string] =
  Parser[string](fn: proc(ctx: var ParseContext, attr: var string): bool =
    let saved = save(ctx)
    for c in s:
      let got = peek(ctx)
      if got.isNone or got.get != c:
        restore(ctx, saved)
        return false
      advance(ctx)
    attr = s
    true
  )

# ── Skipper ──────────────────────────────────────────────────────────────────
let spaceChar*: Parser[Void] =
  omit(satisfy(proc(c: char): bool = c in {' ', '\t', '\n', '\r'}))

proc skipMany*(p: Parser[Void]): Parser[Void] =
  Parser[Void](fn: proc(ctx: var ParseContext, attr: var Void): bool =
    while true:
      let s = save(ctx)
      var dummy: Void
      if not p.fn(ctx, dummy):
        restore(ctx, s)
        break
    true
  )

let space*: Parser[Void] = skipMany(spaceChar)

proc token*[A](p: Parser[A], skip: Parser[Void] = space): Parser[A] =
  Parser[A](fn: proc(ctx: var ParseContext, attr: var A): bool =
    var dummy: Void
    discard skip.fn(ctx, dummy)
    if p.fn(ctx, attr):
      discard skip.fn(ctx, dummy)
      true
    else: false
  )

# ── Комбинаторы ─────────────────────────────────────────────────────────────

# optional: ?p → Parser[Option[A]]
proc `?`*[A](p: Parser[A]): Parser[Option[A]] =
  Parser[Option[A]](fn: proc(ctx: var ParseContext,
                              attr: var Option[A]): bool =
    let saved = save(ctx)
    var inner: A
    if p.fn(ctx, inner): attr = some(inner)
    else:
      restore(ctx, saved)
      attr = none(A)
    true
  )

# optional Void → тоже Void (не оборачиваем в Option)
proc `?`*(p: Parser[Void]): Parser[Void] =
  Parser[Void](fn: proc(ctx: var ParseContext, attr: var Void): bool =
    let saved = save(ctx)
    var dummy: Void
    if not p.fn(ctx, dummy): restore(ctx, saved)
    true
  )

# ── >> с автоколлапсом Void ─────────────────────────────────────────────────

# Void >> Void → Void
proc `>>`*(p: Parser[Void], q: Parser[Void]): Parser[Void] =
  Parser[Void](fn: proc(ctx: var ParseContext, attr: var Void): bool =
    let saved = save(ctx)
    var d: Void
    if p.fn(ctx, d) and q.fn(ctx, d): true
    else:
      restore(ctx, saved)
      false
  )

# Void >> A → A
proc `>>`*[A](p: Parser[Void], q: Parser[A]): Parser[A] =
  Parser[A](fn: proc(ctx: var ParseContext, attr: var A): bool =
    let saved = save(ctx)
    var d: Void
    if p.fn(ctx, d) and q.fn(ctx, attr): true
    else:
      restore(ctx, saved)
      false
  )

# A >> Void → A
proc `>>`*[A](p: Parser[A], q: Parser[Void]): Parser[A] =
  Parser[A](fn: proc(ctx: var ParseContext, attr: var A): bool =
    let saved = save(ctx)
    var d: Void
    if p.fn(ctx, attr) and q.fn(ctx, d): true
    else:
      restore(ctx, saved)
      false
  )

# A >> B → (A, B)
proc `>>`*[A, B](p: Parser[A], q: Parser[B]): Parser[(A, B)] =
  Parser[(A, B)](fn: proc(ctx: var ParseContext,
                           attr: var (A, B)): bool =
    let saved = save(ctx)
    if p.fn(ctx, attr[0]) and q.fn(ctx, attr[1]): true
    else:
      restore(ctx, saved)
      false
  )

# ── | альтернатива ───────────────────────────────────────────────────────────
proc `|`*[A](p, q: Parser[A]): Parser[A] =
  Parser[A](fn: proc(ctx: var ParseContext, attr: var A): bool =
    let saved = save(ctx)
    if p.fn(ctx, attr): return true
    restore(ctx, saved)
    q.fn(ctx, attr)
  )

# ── * + ──────────────────────────────────────────────────────────────────────
proc `*`*(p: Parser[Void]): Parser[Void] =
  Parser[Void](fn: proc(ctx: var ParseContext, attr: var Void): bool =
    while true:
      let s = save(ctx)
      var d: Void
      if not p.fn(ctx, d): restore(ctx, s); break
    true
  )

proc `*`*[A](p: Parser[A]): Parser[seq[A]] =
  Parser[seq[A]](fn: proc(ctx: var ParseContext,
                           attr: var seq[A]): bool =
    attr = @[]
    while true:
      let s = save(ctx)
      var item: A
      if not p.fn(ctx, item): restore(ctx, s); break
      attr.add(item)
    true
  )

proc `+`*(p: Parser[Void]): Parser[Void] =
  Parser[Void](fn: proc(ctx: var ParseContext, attr: var Void): bool =
    var d: Void
    if not p.fn(ctx, d): return false
    while true:
      let s = save(ctx)
      if not p.fn(ctx, d): restore(ctx, s); break
    true
  )

proc `+`*[A](p: Parser[A]): Parser[seq[A]] =
  Parser[seq[A]](fn: proc(ctx: var ParseContext,
                           attr: var seq[A]): bool =
    attr = @[]
    var item: A
    if not p.fn(ctx, item): return false
    attr.add(item)
    while true:
      let s = save(ctx)
      var next: A
      if not p.fn(ctx, next): restore(ctx, s); break
      attr.add(next)
    true
  )

# ── % список через разделитель ───────────────────────────────────────────────
proc `%`*[A](p: Parser[A], sep: Parser[Void]): Parser[seq[A]] =
  Parser[seq[A]](fn: proc(ctx: var ParseContext,
                           attr: var seq[A]): bool =
    attr = @[]
    var item: A
    # 0 элементов тоже ok (как в Spirit: p % sep = *(p >> sep) >> p | eps)
    let saved = save(ctx)
    if not p.fn(ctx, item): return true
    attr.add(item)
    while true:
      let s2 = save(ctx)
      var d: Void
      var next: A
      if not sep.fn(ctx, d) or not p.fn(ctx, next):
        restore(ctx, s2); break
      attr.add(next)
    true
  )

# ── Сбор символов в строку ───────────────────────────────────────────────────
proc asString*(p: Parser[seq[char]]): Parser[string] =
  Parser[string](fn: proc(ctx: var ParseContext, attr: var string): bool =
    var cs: seq[char]
    if not p.fn(ctx, cs): return false
    attr = ""
    for c in cs: attr.add(c)
    true
  )

proc asString*(p: Parser[char]): Parser[string] =
  Parser[string](fn: proc(ctx: var ParseContext, attr: var string): bool =
    var c: char
    if not p.fn(ctx, c): return false
    attr = $c
    true
  )

proc asString*(p: Parser[(char, seq[char])]): Parser[string] =
  ## (char, seq[char]) → string  —  первый символ + хвост
  Parser[string](fn: proc(ctx: var ParseContext, attr: var string): bool =
    var pair: (char, seq[char])
    if not p.fn(ctx, pair): return false
    attr = $pair[0]
    for c in pair[1]: attr.add(c)
    true
  )
# ── Семантические действия ────────────────────────────────────────────────────
proc map*[A, B](p: Parser[A], f: proc(a: A): B {.closure.}): Parser[B] =
  Parser[B](fn: proc(ctx: var ParseContext, attr: var B): bool =
    var inner: A
    if p.fn(ctx, inner):
      attr = f(inner)
      true
    else: false
  )

# ── Semantic action: парсер + побочный эффект ────────────────────────────────

## Вызывает f(attr) после успешного разбора.
## f получает уже вычисленный атрибут — можно класть в AST/стек.
proc act*[A](p: Parser[A],
              f: proc(a: A) {.closure.}): Parser[A] =
  Parser[A](fn: proc(ctx: var ParseContext, attr: var A): bool =
    if p.fn(ctx, attr):
      f(attr)
      true
    else: false
  )

## Версия без возврата атрибута (только побочный эффект → Void)
proc actVoid*[A](p: Parser[A],
                  f: proc(a: A) {.closure.}): Parser[Void] =
  Parser[Void](fn: proc(ctx: var ParseContext, attr: var Void): bool =
    var inner: A
    if p.fn(ctx, inner):
      f(inner)
      true
    else: false
  )

## Трансформация: разбор A → производим B
proc map*[A, B](p: Parser[A],
                f: proc(a: A): B {.closure.}): Parser[B] =
  Parser[B](fn: proc(ctx: var ParseContext, attr: var B): bool =
    var inner: A
    if p.fn(ctx, inner):
      attr = f(inner)
      true
    else: false
  )

## Константный атрибут: если разбор успешен — подставить значение
proc val*[A, B](p: Parser[A], v: B): Parser[B] =
  p.map(proc(_: A): B = v)
