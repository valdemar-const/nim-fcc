# parser.nim
import spirit/x3
import std/strformat

type CVoid = Parser[Void]

proc makeCParser*(): CVoid =

  let kw_signed   = token(literal("signed"))
  let kw_unsigned = token(literal("unsigned"))
  let kw_const    = token(literal("const"))
  let kw_volatile = token(literal("volatile"))
  let kw_char     = token(literal("char"))
  let kw_short    = token(literal("short"))
  let kw_int      = token(literal("int"))
  let kw_long     = token(literal("long"))
  let kw_float    = token(literal("float"))
  let kw_double   = token(literal("double"))
  let kw_return   = token(literal("return"))

  # ch(...) вместо char(...)
  let lparen    = token(omit(ch('(')))
  let rparen    = token(omit(ch(')')))
  let lbrace    = token(omit(ch('{')))
  let rbrace    = token(omit(ch('}')))
  let lbraket   = token(omit(ch('[')))
  let rbraket   = token(omit(ch(']')))
  let semicolon = token(omit(ch(';')))
  let comma     = token(omit(ch(',')))
  let star      = token(omit(ch('*')))

  # identifier: первый символ — буква или '_'
  let identFirst = omit(alpha | ch('_'))
  let identRest  = omit(alpha | digit | ch('_'))
  let identifier = token(identFirst >> *identRest)

  # identifier как строка — когда значение нужно
  let identifierStr: Parser[string] =
    token(asString((alpha | ch('_')) >> *(alpha | digit | ch('_'))))

  let numericLiteral = token(omit(+digit))

  let typeQualifier = kw_const | kw_volatile

  let typeName =
    (?kw_signed   >> kw_long >> kw_long)   |
    (?kw_signed   >> kw_long)              |
    (?kw_signed   >> kw_int)               |
    (?kw_signed   >> kw_short)             |
    (?kw_signed   >> kw_char)              |
    (?kw_unsigned >> kw_long >> kw_long)   |
    (?kw_unsigned >> kw_long)              |
    (?kw_unsigned >> kw_int)               |
    (?kw_unsigned >> kw_short)             |
    (?kw_unsigned >> kw_char)              |
    (kw_long >> kw_double)                 |
    kw_double                              |
    kw_float                               |
    identifier

  let pointer = *(star >> ?typeQualifier)

  # forward declarations через замыкания
  var declaratorFn: proc(ctx: var ParseContext, a: var Void): bool {.closure.}
  var exprFn:       proc(ctx: var ParseContext, a: var Void): bool {.closure.}
  var funcParamsFn: proc(ctx: var ParseContext, a: var Void): bool {.closure.}

  let declarator = Parser[Void](fn: proc(ctx: var ParseContext,
                                          a: var Void): bool =
    declaratorFn(ctx, a))
  let expr       = Parser[Void](fn: proc(ctx: var ParseContext,
                                          a: var Void): bool =
    exprFn(ctx, a))
  let funcParams = Parser[Void](fn: proc(ctx: var ParseContext,
                                          a: var Void): bool =
    funcParamsFn(ctx, a))

  exprFn = numericLiteral.fn

  let arraySize  = lbraket >> ?expr >> rbraket
  let postfix    = *(arraySize | funcParams)
  let directDecl = (identifier | (lparen >> declarator >> rparen)) >> postfix

  declaratorFn = (pointer >> directDecl).fn

  let typeDef         = *typeQualifier >> typeName >> declarator
  let formalParam     = typeDef
  let formalParamList = formalParam % comma

  funcParamsFn = (lparen >> omit(formalParamList) >> rparen).fn

  let stmtReturn   = kw_return >> expr
  let funcStmt     = stmtReturn >> semicolon
  let funcStmtList = *funcStmt
  let funcBody     = lbrace >> funcStmtList >> rbrace
  let funcDef      = typeDef >> funcBody

  +funcDef

# ── API ──────────────────────────────────────────────────────────────────────

type ParserLangC* = object
  impl: Parser[Void]

proc newParserLangC*(): ParserLangC =
  ParserLangC(impl: makeCParser())

proc parse*(p: ParserLangC, source: string): bool =
  var ctx = ParseContext(input: source, pos: 0)
  var dummy: Void
  let ok = p.impl.fn(ctx, dummy)
  echo fmt"source.len: {source.len}, stream.pos: {ctx.pos}"
  ok and ctx.pos == source.len
