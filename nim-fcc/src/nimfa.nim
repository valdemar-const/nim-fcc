import nimfa/parser

import cligen

from std/os       import fileExists
from std/sequtils import apply
from std/sugar    import `=>`
import std/strformat
import std/options

# -- Entry point

proc nimfa(sources: seq[string], verbose: bool = false) =
  let checkFileExists = (filename: string) => (if fileExists(filename): some(filename) else: none(string))
  let fileExistsStatus = (filename: string) => (if checkFileExists(filename).isSome: "exists" else: "does not exist")
  let showFileStatus = (source: string) => echo(fmt"{source}: {fileExistsStatus(source)}")

  if verbose:
    apply(sources, showFileStatus)

  for source in sources:
    if verbose:
      echo(fmt"parse: {source}")
    let parser = newParserLangC()
    echo(fmt"{parser.parse(readFile(source))}")

when isMainModule:
  dispatch(nimfa)
