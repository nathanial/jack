import Lake
open Lake DSL System

package jack where
  version := v!"0.1.0"

require crucible from git "https://github.com/nathanial/crucible" @ "v0.0.9"

-- FFI: Build socket C code
target socket_ffi_o pkg : FilePath := do
  let oFile := pkg.buildDir / "ffi" / "socket.o"
  let srcJob ← inputTextFile <| pkg.dir / "ffi" / "socket.c"
  let leanIncludeDir ← getLeanIncludeDir
  let weakArgs := #["-I", leanIncludeDir.toString]
  buildO oFile srcJob weakArgs #["-fPIC", "-O2"] "cc" getLeanTrace

extern_lib jack_native pkg := do
  let name := nameToStaticLib "jack_native"
  let ffiO ← socket_ffi_o.fetch
  buildStaticLib (pkg.buildDir / "lib" / name) #[ffiO]

@[default_target]
lean_lib Jack where
  roots := #[`Jack]

lean_lib Tests where
  roots := #[`Tests]

@[test_driver]
lean_exe jack_tests where
  root := `Tests.Main
