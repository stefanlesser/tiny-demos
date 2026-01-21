#!/bin/bash

# Direct build script that compiles everything without Swift Package Manager
# This recreates the original 64k demo compilation approach with embedded shader

echo "Building 64k demo with embedded Metal library (direct compilation)..."
echo ""

# Step 1: Precompile Metal shader
echo "1. Compiling Metal shader..."
xcrun -sdk macosx metal Sources/Shaders.metal -o Shaders.metallib
if [ $? -ne 0 ]; then
    echo "✗ Failed to compile Metal shader"
    exit 1
fi
echo "✓ Metal shader compiled successfully"

# Step 2: Compile Swift with embedded shader library
echo "2. Compiling Swift executable with embedded shader..."
swiftc Sources/64kDemo/main.swift -o MetalApp \
    -Osize -whole-module-optimization \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __metallib -Xlinker Shaders.metallib \
    -Xlinker -dead_strip -Xlinker -x \
    -Xfrontend -disable-reflection-metadata \
    -Xfrontend -disable-reflection-names \
    -Xcc -fno-stack-protector

if [ $? -ne 0 ]; then
    echo "✗ Failed to compile Swift executable"
    exit 1
fi
echo "✓ Swift executable compiled successfully"

# Step 3: Compress the binary (as in original 64k demo)
echo "3. Compressing binary..."
gzexe MetalApp
if [ $? -ne 0 ]; then
    echo "✗ Failed to compress binary"
    exit 1
fi
echo "✓ Binary compressed successfully"

# Step 4: Show final size
echo ""
echo "Final binary details:"
ls -la MetalApp*
echo ""
echo "✓ 64k demo built successfully with embedded shader library!"
