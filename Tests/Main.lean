import Crucible
open Crucible

testSuite "Jack"

test "placeholder" := do
  (1 + 1) ≡ 2

def main : IO UInt32 := runAllSuites
