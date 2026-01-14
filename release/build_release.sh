#!/bin/bash
# Squish Release Build Script
# Reads version info from dist.info and builds release packages

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root
cd "$PROJECT_ROOT"

# Read dist.info
echo "Reading dist.info..."
DIST_INFO=$(<dist.info)

# Parse version
VERSION=$(echo "$DIST_INFO" | grep -oP 'version\s*=\s*"\K[^"]+' || echo "")
if [ -z "$VERSION" ]; then
    echo "ERROR: Could not find version in dist.info"
    exit 1
fi

# Parse name
NAME=$(echo "$DIST_INFO" | grep -oP 'name\s*=\s*"\K[^"]+' || echo "squish")

echo "Building $NAME version $VERSION"

# Create dist directory
DIST_DIR="$SCRIPT_DIR/dist"
if [ "$1" = "--clean" ] && [ -d "$DIST_DIR" ]; then
    echo "Cleaning dist directory..."
    rm -rf "$DIST_DIR"
fi

if [ ! -d "$DIST_DIR" ]; then
    mkdir -p "$DIST_DIR"
fi

# List of variants to build
declare -a VARIANTS=(
    "|base"
    "-minify|with minify"
    "-uglify|with uglify"
    "-minify-uglify|with minify and uglify"
    "-debug|with debug"
    "-all|with all modules"
)

for variant_info in "${VARIANTS[@]}"; do
    IFS='|' read -r variant_name variant_desc <<< "$variant_info"
    PACKAGE_NAME="${NAME}-${VERSION}${variant_name}"
    PACKAGE_DIR="$DIST_DIR/$PACKAGE_NAME"

    echo ""
    echo "Building ${PACKAGE_NAME} ($variant_desc)..."

    # Create package directory
    if [ -d "$PACKAGE_DIR" ]; then
        rm -rf "$PACKAGE_DIR"
    fi
    mkdir -p "$PACKAGE_DIR"

    # Build with appropriate squishy
    SQUISHY_FILE="squishy"
    TEMP_SQUISHY=false

    if [ "$variant_name" = "-minify" ]; then
        # Create minify squishy
        SQUISHY_FILE="squishy.tmp"
        TEMP_SQUISHY=true
        cat squishy > "$SQUISHY_FILE"
        cat >> "$SQUISHY_FILE" << 'EOF'
Module "squish.minify" "minify/squish.minify.lua"
Module "optlex" "minify/optlex.lua"
Module "optparser" "minify/optparser.lua"
Module "llex" "minify/llex.lua"
Module "lparser" "minify/lparser.lua"
EOF
    elif [ "$variant_name" = "-uglify" ]; then
        # Create uglify squishy
        SQUISHY_FILE="squishy.tmp"
        TEMP_SQUISHY=true
        cat squishy > "$SQUISHY_FILE"
        cat >> "$SQUISHY_FILE" << 'EOF'
Module "squish.uglify" "uglify/squish.uglify.lua"
Module "uglify.llex" "uglify/llex.lua"
EOF
    elif [ "$variant_name" = "-minify-uglify" ]; then
        # Create combined squishy
        SQUISHY_FILE="squishy.tmp"
        TEMP_SQUISHY=true
        cat squishy > "$SQUISHY_FILE"
        cat >> "$SQUISHY_FILE" << 'EOF'
Module "squish.minify" "minify/squish.minify.lua"
Module "optlex" "minify/optlex.lua"
Module "optparser" "minify/optparser.lua"
Module "llex" "minify/llex.lua"
Module "lparser" "minify/lparser.lua"
Module "squish.uglify" "uglify/squish.uglify.lua"
Module "uglify.llex" "uglify/llex.lua"
EOF
    elif [ "$variant_name" = "-debug" ]; then
        # Create debug squishy
        SQUISHY_FILE="squishy.tmp"
        TEMP_SQUISHY=true
        cat squishy > "$SQUISHY_FILE"
        cat >> "$SQUISHY_FILE" << 'EOF'
Module "squish.debug" "debug/squish.debug.lua"
Module "debug.minichunkspy" "debug/minichunkspy.lua"
EOF
    elif [ "$variant_name" = "-all" ]; then
        # Create combined squishy with all modules
        SQUISHY_FILE="squishy.tmp"
        TEMP_SQUISHY=true
        cat squishy > "$SQUISHY_FILE"
        cat >> "$SQUISHY_FILE" << 'EOF'
Module "squish.minify" "minify/squish.minify.lua"
Module "optlex" "minify/optlex.lua"
Module "optparser" "minify/optparser.lua"
Module "llex" "minify/llex.lua"
Module "lparser" "minify/lparser.lua"
Module "squish.uglify" "uglify/squish.uglify.lua"
Module "uglify.llex" "uglify/llex.lua"
Module "squish.debug" "debug/squish.debug.lua"
Module "debug.minichunkspy" "debug/minichunkspy.lua"
Module "squish.gzip" "gzip/squish.gzip.lua"
Module "gzip.deflatelua" "gzip/deflatelua.lua"
EOF
    fi

    # Copy squishy file to root if not already there, then run squish
    echo "  Running squish with $SQUISHY_FILE..."
    if [ "$SQUISHY_FILE" != "squishy" ]; then
        # Backup original squishy and use the variant
        mv squishy squishy.backup
        cp "$SQUISHY_FILE" squishy
        lua squish.lua
        # Restore original squishy
        mv squishy.backup squishy
    else
        lua squish.lua
    fi

    # Clean up temp squishy if created
    if [ "$TEMP_SQUISHY" = true ]; then
        rm -f "$SQUISHY_FILE"
    fi

    # Copy files to package
    echo "  Copying files..."
    cp squish "$PACKAGE_DIR/"
    cp README.md "$PACKAGE_DIR/"
    cp COPYRIGHT "$PACKAGE_DIR/"
    cp CHANGES "$PACKAGE_DIR/"
    cp dist.info "$PACKAGE_DIR/"

    # Create archive
    ARCHIVE_NAME="${PACKAGE_NAME}.tar.gz"
    ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"
    echo "  Creating archive $ARCHIVE_NAME..."
    tar -czf "$ARCHIVE_PATH" -C "$PACKAGE_DIR" .

    # Clean up package directory
    rm -rf "$PACKAGE_DIR"

    echo "  Created $ARCHIVE_NAME"
done

echo ""
echo "Build complete! Packages created in release/dist/"
echo ""
echo "Packages:"
ls -1 "$DIST_DIR"/*.tar.gz | xargs -n1 basename

# Keep terminal open on error
if [ $? -ne 0 ]; then
    echo ""
    read -p "Press Enter to continue..."
fi
