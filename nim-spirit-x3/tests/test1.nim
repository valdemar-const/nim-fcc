import unittest
import spirit/x3 as x3

test "parse one char":
  let p = x3.char('a')
  check x3.parse(p, "a")
  check not x3.parse(p, "b")

test "identifier":
  # identifier = (alpha | '_') >> *(alpha | digit | '_')
  let identifier = (x3.alpha | x3.char('_')) >> *(x3.alpha | x3.digit | x3.char('_'))
  check x3.parse(identifier, "hello123_world")
  check not x3.parse(identifier, "123abc")
