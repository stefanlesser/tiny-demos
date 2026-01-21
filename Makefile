# Makefile for 64k Demo build process
# Combines functionality of build-direct.sh and build-shaders.sh

.PHONY: all clean shaders direct build run run-gz show-size compressed

# Default target
all: direct

# Build with direct compilation (like build-direct.sh)
direct: Shaders.metallib MetalApp

# Build shaders only
shaders: Shaders.metallib

# Compile the Metal shader
Shaders.metallib: Sources/Shaders.metal
	@echo "1. Compiling Metal shader..."
	xcrun -sdk macosx metal Sources/Shaders.metal -o Shaders.metallib
	@echo "✓ Metal shader compiled successfully"

# Build the Swift executable with embedded shader
MetalApp: Shaders.metallib Sources/64kDemo/main.swift
	@echo "2. Compiling Swift executable with embedded shader..."
	swiftc Sources/64kDemo/main.swift -o MetalApp \
		-Osize -whole-module-optimization \
		-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __metallib -Xlinker Shaders.metallib \
		-Xlinker -dead_strip -Xlinker -x \
		-Xfrontend -disable-reflection-metadata \
		-Xfrontend -disable-reflection-names \
		-Xcc -fno-stack-protector
	@echo "✓ Swift executable compiled successfully"

# Compress the binary (as in original 64k demo)
MetalApp.gz: MetalApp
	@echo "3. Compressing binary..."
	gzexe MetalApp
	@echo "✓ Binary compressed successfully"

# Build with Swift Package Manager (like build-shaders.sh)
build: Shaders.metallib
	@echo "Rebuilding Swift package..."
	swift build
	@echo "✓ Swift package rebuilt successfully"

# Build everything with compressed binary (combined direct + compression)
compressed: Shaders.metallib MetalApp.gz
	@echo ""
	@echo "Final binary details:"
	ls -la MetalApp*

# Clean up build artifacts
clean:
	rm -f Shaders.metallib MetalApp MetalApp~

# Show final size
show-size: MetalApp
	@echo "Final binary details:"
	ls -la MetalApp*

# Run the built application (using the compressed version)
run: compressed
	./MetalApp

# Run with compressed binary (using the compressed version)
run-gz: compressed
	./MetalApp