# AGENTS.md

## Codebase Overview
This is a Swift/Metal 64k demo project that compiles a Metal shader and embeds it into a Swift executable. The codebase is designed for size-constrained compilation with specific optimization flags.

## Build/Lint/Test Commands

### Build Commands
- `make direct` - Compile Metal shader and Swift executable with embedded shader (like build-direct.sh)
- `make shaders` - Compile only the Metal shader (like build-shaders.sh)
- `make compressed` - Build everything with compressed binary output
- `make build` - Rebuild using Swift Package Manager
- `make clean` - Remove all build artifacts

### Running Tests
There are no explicit test files in this codebase, but you can run:
- `make run` - Execute the built application
- `make run-gz` - Execute the compressed binary

### Build Process Details
The build process follows these steps:
1. Compile Metal shader using `xcrun -sdk macosx metal Sources/Shaders.metal -o Shaders.metallib`
2. Compile Swift executable with embedded shader library using specific optimization flags:
   - `-Osize -whole-module-optimization`
   - `-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __metallib -Xlinker Shaders.metallib`
   - `-Xlinker -dead_strip -Xlinker -x`
   - `-Xfrontend -disable-reflection-metadata -Xfrontend -disable-reflection-names`
   - `-Xcc -fno-stack-protector`

### Compression
Binary compression is handled by `gzexe MetalApp` which creates a compressed executable and saves the original as `MetalApp~`.

## Code Style Guidelines

### Swift Style
- Use descriptive variable and function names (e.g., `startTime` instead of `t`)
- Follow Swift naming conventions with PascalCase for types and camelCase for variables/functions
- Use `let` for immutable values, `var` for mutable ones
- Prefer explicit type annotations where clarity improves readability

### Imports and Dependencies
- Import only what's necessary (`Cocoa`, `MetalKit`)
- Group imports logically with system frameworks first, then project-specific
- Avoid wildcard imports (`import *`)
- Use qualified names when needed to avoid ambiguity

### Formatting
- Use 4 spaces for indentation (not tabs)
- No trailing whitespace on lines
- One blank line between top-level declarations
- No extra blank lines within function bodies
- Place opening braces on the same line as control statements

### Types and Variables
- Use `SIMD2<Float>` for vector types
- Prefer type inference over explicit typing when it improves readability
- Use `let` for constants and immutable values
- Use `var` for mutable state

### Naming Conventions
- PascalCase for type names (classes, structs, enums)
- camelCase for function and variable names
- Use descriptive names that clearly indicate purpose (e.g., `startTime`, `resolution`)
- Prefix private methods with underscore (e.g., `_setupView`)

### Error Handling
- Use guard statements to handle preconditions and early returns
- Follow the pattern of checking for errors with `guard let` or `if let`
- Use fatalError() appropriately for unrecoverable conditions
- Handle errors gracefully when possible, with descriptive messages

### Memory and Performance
- Use whole-module optimization (`-Osize -whole-module-optimization`)
- Apply dead code stripping (`-Xlinker -dead_strip`)
- Disable reflection metadata for size optimization
- Use proper resource management and cleanup

### Code Organization
- Keep functions focused on a single responsibility
- Break complex logic into smaller, well-named helper functions
- Group related functionality together in logical sections
- Use comments to explain "why" not "what"

### Metal Shader Integration
- Follow the pattern of loading embedded resources using `_dyld_get_image_header` and `getsectiondata`
- Handle fallback cases for resource loading (e.g., when not embedded)
- Ensure proper error handling when accessing the embedded Metal library

### Testing Considerations
- No unit tests exist in this codebase, but tests should validate:
  - Shader compilation succeeds
  - Embedded library loading works correctly  
  - Application runs without crashes
- All tests should be fast and deterministic

### Swift Package Manager Integration
- The project uses a `Package.swift` that copies the embedded shader library as a resource
- Ensure any changes to the shader or build process are reflected in the package configuration

## Special Considerations

### 64k Size Constraints
- The project is optimized for size-constrained compilation
- Use `-Osize` optimization to reduce binary size
- Apply `-dead_strip` to remove unused symbols
- Disable reflection metadata and names to reduce binary size

### Binary Compression
- The project includes compression via `gzexe` as part of the build process
- When running compressed binaries, ensure they're properly decompressed on execution

### Resource Management
- The code uses embedded Metal libraries through section creation (`-sectcreate`)
- Ensure the embedded resource loading logic works both in development and deployment contexts

### Platform Compatibility
- The project targets macOS 12.0+ with Metal support
- All code assumes availability of Metal and Cocoa frameworks

## Additional Notes
This project is designed as a size-constrained demo with specific build requirements. The Makefile and shell scripts provide the necessary build automation, while the Swift code demonstrates proper Metal integration with embedded shader libraries. The code is optimized for size and performance constraints typical in 64k demos.