# ast.nim
type
  TypeKind* = enum
    tkChar, tkShort, tkInt, tkLong, tkLongLong,
    tkFloat, tkDouble, tkLongDouble,
    tkUChar, tkUShort, tkUInt, tkULong, tkULongLong,
    tkNamed

  TypeQual* = enum
    tqConst, tqVolatile

  CType* = object
    kind*:   TypeKind
    quals*:  seq[TypeQual]
    name*:   string          # для tkNamed

  Declarator* = object
    name*:    string
    ptrDepth*: int           # кол-во *

  VarDecl* = object
    typ*:  CType
    decl*: Declarator

  ReturnStmt* = object
    value*: int              # пока только числа

  FuncDef* = object
    ret*:    VarDecl
    params*: seq[VarDecl]
    body*:   seq[ReturnStmt]

  CModule* = object
    funcs*: seq[FuncDef]
