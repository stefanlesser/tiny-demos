Quick test for a 64k demo based on Swift and Metal.

To compile use this command:

```sh
swiftc main.swift -o MetalApp \
  -Osize -whole-module-optimization \
  -Xlinker -dead_strip -Xlinker -x \
  -Xfrontend -disable-reflection-metadata \
  -Xfrontend -disable-reflection-names \
  -Xcc -fno-stack-protector
```

Then compress the resulting binary with this command:

```sh
gzexe MetalApp
```
