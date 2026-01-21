#!/bin/bash

# Build script for compiling Metal shaders and updating the Swift package
# This script automates the process of rebuilding the Metal library when shaders change

echo "Building Metal shaders..."

# Compile the Metal shader
xcrun -sdk macosx metal Sources/Shaders.metal -o Shaders.metallib

if [ $? -eq 0 ]; then
    echo "✓ Metal shader compilation successful"

    # Verify the file was created
    if [ -f "Shaders.metallib" ]; then
        echo "✓ Shaders.metallib created successfully"

        # Rebuild the Swift package to include updated shader
        echo "Rebuilding Swift package..."
        swift build

        if [ $? -eq 0 ]; then
            echo "✓ Swift package rebuilt successfully"
            echo "✓ Shader update complete!"
        else
            echo "✗ Swift package build failed"
            exit 1
        fi
    else
        echo "✗ Failed to create Shaders.metallib"
        exit 1
    fi
else
    echo "✗ Metal shader compilation failed"
    exit 1
fi
