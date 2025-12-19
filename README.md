Quick test for a 64k demo based on Swift and Metal.

1. Precompile Metal shader:

```sh
xcrun -sdk macosx metal Shaders.metal -o Shaders.metallib
```

2. Then compile with embedding precompiled shader using this command:

```sh
swiftc main.swift -o MetalApp \
-Osize -whole-module-optimization \
-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __metallib -Xlinker Shaders.metallib \
-Xlinker -dead_strip -Xlinker -x \
-Xfrontend -disable-reflection-metadata \
-Xfrontend -disable-reflection-names \
-Xcc -fno-stack-protector \
```

Then compress the resulting binary with this command:

```sh
gzexe MetalApp
```
