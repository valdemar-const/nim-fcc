import spirit

import std/sugar
import std/strformat

proc make_c_spirit_parser(): Parser =
  # grammar

  # grammar: keywords

  let kw_signed   = x3.token(x3.literal("signed"))
  let kw_unsigned = x3.token(x3.literal("unsigned"))
  let kw_const    = x3.token(x3.literal("const"))
  let kw_volatile = x3.token(x3.literal("volatile"))
  let kw_char     = x3.token(x3.literal("char"))
  let kw_short    = x3.token(x3.literal("short"))
  let kw_int      = x3.token(x3.literal("int"))
  let kw_long     = x3.token(x3.literal("long"))
  let kw_float    = x3.token(x3.literal("float"))
  let kw_double   = x3.token(x3.literal("double"))
  let kw_return   = x3.token(x3.literal("return"))

  # grammar: delimetrs

  let lparen    = x3.token(x3.char('('))
  let rparen    = x3.token(x3.char(')'))
  let lbrace    = x3.token(x3.char('{'))
  let rbrace    = x3.token(x3.char('}'))
  let semicolon = x3.token(x3.char(';'))
  let comma     = x3.token(x3.char(','))
  let star      = x3.token(x3.char('*'))

  # grammar: atoms

  let identifier      = (x3.alpha | x3.char('_')) >> *(x3.alpha | x3.digit | x3.char('_'))
  let numeric_literal = +(x3.digit)

  # grammar: types

  # [volatile | const]
  # [ signed | unsigned ], char, short, int, long, long long
  # float, double, long double

  let type_basic_char       = ?(kw_signed) >> kw_char
  let type_basic_short      = ?(kw_signed) >> kw_short
  let type_basic_int        = ?(kw_signed) >> kw_int
  let type_basic_long       = ?(kw_signed) >> kw_long
  let type_basic_long_long  = ?(kw_signed) >> kw_long >> kw_long

  let type_basic_uchar      = ?(kw_unsigned) >> kw_char
  let type_basic_ushort     = ?(kw_unsigned) >> kw_short
  let type_basic_uint       = ?(kw_unsigned) >> kw_int
  let type_basic_ulong      = ?(kw_unsigned) >> kw_long
  let type_basic_ulong_long = ?(kw_unsigned) >> kw_long >> kw_long

  let type_name = type_basic_int | identifier

  let type_qualifier = kw_const | kw_volatile

  let basic_type     = *type_qualifier >> type_name
  let type_def       = basic_type

  # grammar: expressions
  let expr = numeric_literal

  # grammar function definition

  let stmt_return = kw_return >> expr
  let func_stmt = stmt_return >> semicolon
  let func_stmt_list = *func_stmt
  let func_body = lbrace >> func_stmt_list >> rbrace
  let formal_param = (type_def >> ?(identifier))
  let formal_param_list = formal_param % comma
  let func_def = type_def >> identifier >> lparen >> formal_param_list >> rparen >> func_body
  let func_def_list = +func_def

  let c_module = func_def_list
  c_module

# parser

type ParserLangC* = object
  parser_impl: x3.Parser

proc newParserLangC*(): ParserLangC =
  let c_parser = make_c_spirit_parser()
  result = ParserLangC(parser_impl: (stream: var x3.Stream) => (c_parser(stream)))

proc parse*(p: ParserLangC, source: string): bool =
  var stream = x3.newStringStream(source)
  let parsed = p.parser_impl(stream)
  echo(fmt"source.len: {source.len}, stream.pos: {stream.pos}")
  parsed and x3.pos(stream) == source.len
