#!/bin/bash

# Factorio Mod Build Script
# Reads version from info.json and creates properly named zip file

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "info.json" ]; then
    print_error "info.json not found. Make sure you're in the mod directory."
    exit 1
fi

# Extract mod name and version from info.json
print_status "Reading mod information from info.json..."

# Check if jq is available (preferred method)
if command -v jq &> /dev/null; then
    MOD_NAME=$(jq -r '.name' info.json)
    MOD_VERSION=$(jq -r '.version' info.json)
else
    print_warning "jq not found, using sed parsing (less reliable)"
    # Fallback to sed/grep parsing
    MOD_NAME=$(grep '"name"' info.json | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    MOD_VERSION=$(grep '"version"' info.json | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

# Validate extracted values
if [ -z "$MOD_NAME" ] || [ -z "$MOD_VERSION" ]; then
    print_error "Failed to extract mod name or version from info.json"
    print_error "Name: '$MOD_NAME', Version: '$MOD_VERSION'"
    exit 1
fi

print_status "Mod Name: $MOD_NAME"
print_status "Version: $MOD_VERSION"

# Create zip filename
ZIP_NAME="${MOD_NAME}_${MOD_VERSION}.zip"
print_status "Creating zip file: $ZIP_NAME"

# Remove existing zip if it exists
if [ -f "$ZIP_NAME" ]; then
    print_warning "Removing existing $ZIP_NAME"
    rm "$ZIP_NAME"
fi

# Get the parent directory name (should match mod name)
CURRENT_DIR=$(basename "$PWD")

# Create the zip file
if [ "$CURRENT_DIR" = "$MOD_NAME" ]; then
    # We're in the mod directory, zip from parent
    print_status "Zipping from parent directory..."
    cd ..
    zip -r "$ZIP_NAME" "$MOD_NAME/" \
        -x "$MOD_NAME/.git/*" \
        -x "$MOD_NAME/.gitignore" \
        -x "$MOD_NAME/build-mod.sh" \
        -x "$MOD_NAME/*.zip" \
        -x "$MOD_NAME/.vscode/*" \
        -x "$MOD_NAME/.idea/*" \
        -x "$MOD_NAME/.*"
    
    # Move zip file into mod directory
    mv "$ZIP_NAME" "$MOD_NAME/"
    cd "$MOD_NAME"
else
    print_warning "Directory name '$CURRENT_DIR' doesn't match mod name '$MOD_NAME'"
    print_status "Creating zip with correct structure..."
    
    # Create temporary directory with correct name
    TEMP_DIR="/tmp/${MOD_NAME}_build_$$"
    mkdir -p "$TEMP_DIR"
    
    # Copy files to temp directory with correct mod name
    cp -r . "$TEMP_DIR/$MOD_NAME"
    
    # Remove unwanted files from temp copy
    rm -rf "$TEMP_DIR/$MOD_NAME/.git"
    rm -f "$TEMP_DIR/$MOD_NAME/.gitignore"
    rm -f "$TEMP_DIR/$MOD_NAME/build-mod.sh"
    rm -f "$TEMP_DIR/$MOD_NAME"/*.zip
    rm -rf "$TEMP_DIR/$MOD_NAME/.vscode"
    rm -rf "$TEMP_DIR/$MOD_NAME/.idea"
    
    # Create zip from temp directory
    cd "$TEMP_DIR"
    zip -r "$ZIP_NAME" "$MOD_NAME/"
    
    # Move zip back to original location
    mv "$ZIP_NAME" "$OLDPWD/"
    
    # Clean up temp directory
    rm -rf "$TEMP_DIR"
    
    # Go back to original directory
    cd "$OLDPWD"
fi

# Verify zip file was created
if [ -f "$ZIP_NAME" ]; then
    ZIP_SIZE=$(du -h "$ZIP_NAME" | cut -f1)
    print_success "Mod zip created: $ZIP_NAME ($ZIP_SIZE)"
    
    # Show zip contents for verification
    print_status "Zip contents:"
    unzip -l "$ZIP_NAME" | head -20
    
    # Optional: Copy to Factorio mods directory
    FACTORIO_MODS_DIR="$HOME/.factorio/mods"
    if [ -d "$FACTORIO_MODS_DIR" ]; then
        read -p "Copy to Factorio mods directory? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$ZIP_NAME" "$FACTORIO_MODS_DIR/"
            print_success "Copied to $FACTORIO_MODS_DIR/"
        fi
    else
        print_warning "Factorio mods directory not found at $FACTORIO_MODS_DIR"
    fi
    
else
    print_error "Failed to create zip file"
    exit 1
fi

print_success "Build complete!"