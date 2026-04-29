# Package

version       = "0.1.0"
author        = "Vladimir Novikov"
description   = "Nimfa - a Nim written ANSI C compiler with fasm2/fasmg backend."
license       = "Apache-2.0"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nimfa"]


# Dependencies

requires "nim >= 2.2.8"
requires "cligen"
requires "spirit"
