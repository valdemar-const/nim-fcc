# This is just an example to get you started. Users of your hybrid library will
# import this file by writing ``import nim_fccpkg/submodule``. Feel free to rename or
# remove this file altogether. You may create additional modules alongside
# this file as required.
import std/strformat

proc getWelcomeMessage*(who: string): string = fmt"Hello, {who}!"
