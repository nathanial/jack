import Lake
open Lake DSL

package jack where
  version := v!"0.1.0"

require crucible from git "https://github.com/nathanial/crucible" @ "v0.0.9"

@[default_target]
lean_lib Jack where
  roots := #[`Jack]

lean_lib Tests where
  roots := #[`Tests]

@[test_driver]
lean_exe jack_tests where
  root := `Tests.Main
