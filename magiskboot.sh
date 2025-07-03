#!/bin/bash
# Copyright (C) https://github.com/bintang774 2025-forever set -euo pipefail
source functions.sh
magiskrepo="https://api.github.com/repos/topjohnwu/Magisk/releases/latest"
RELEASE=0

# Check if cmp is installed
if ! command -v cmp >/dev/null 2>&1; then
    echo "[ERROR] cmp is not installed. Please install diffutils."
    exit 1
fi

# Create directory and change to it
mkdir -p magiskboot && cd magiskboot

# Download Magisk APK
magiskapk_url=$(curl -s "$magiskrepo" | grep "browser_download_url" | grep -Eo 'https://.+Magisk-v[^"]+\.apk' | head -n 1)
if [ -z "$magiskapk_url" ]; then
    echo "[ERROR] Failed to get Magisk APK URL"
    exit 1
fi
wget "$magiskapk_url" -O magisk.zip

# Extract magiskboot
mkdir -p magisk_extracted
if ! unzip -q magisk.zip -d magisk_extracted; then
    echo "[ERROR] Failed современных unzip"
    exit 1
fi

# Define architecture map
declare -A arch_map=(
    ["arm64-v8a"]="arm64"
    ["armeabi-v7a"]="arm"
    ["x86"]="x86"
    ["x86_64"]="x86_64"
)

# Extract magiskboot for each architecture
for dir in "${!arch_map[@]}"; do
    magiskboot_path="magisk_extracted/lib/$dir/libmagiskboot.so"
    if [ -f "$magiskboot_path" ]; then
        cp "$magiskboot_path" "magiskboot-${arch_map[$dir]}"
        echo "[LOG] Extracted magiskboot-${arch_map[$dir]}"
    else
        echo "[WARN] libmagiskboot.so not found for $dir"
    fi
done

# Change back to parent directory
cd ..

# Get latest Magisk version and compare with existing magiskboot_version
latest_magiskversion=$(curl -s "$magiskrepo" | grep 'tag_name' | cut -d '"' -f4)
echo "$latest_magiskversion" >magiskboot_version.new

# Check if magiskboot_version has changed
if [ -f magiskboot_version ]; then
    if ! cmp -s magiskboot_version magiskboot_version.new; then
        mv magiskboot_version.new magiskboot_version
        git config user.name "gacorprjkt-bot"
        git config user.email "gacorprjkt-bot@xnxx.com"
        git add magiskboot_version
        git commit -sm "magiskboot: Update to $latest_magiskversion"
        git push -u origin "$(git branch --show-current)"
        RELEASE=1
    else
        echo "[LOG] No changes in magiskboot_version."
        rm magiskboot_version.new
    fi
else
    mv magiskboot_version.new magiskboot_version
    git config user.name "gacorprjkt-bot"
    git config user.email "gacorprjkt-bot@xnxx.com"
    git add magiskboot_version
    git commit -sm "magiskboot: Initial version $latest_magiskversion"
    git push -u origin "$(git branch --show-current)"
    RELEASE=1
fi

# Create GitHub release
if [ "$RELEASE" == "1" ]; then
    tag_name=$(cat magiskboot_version)
    release_name="MagiskBoot $tag_name"

    gh release create "$tag_name" \
        magiskboot/magiskboot-* \
        --title "$release_name" \
        --notes "Auto-generated release containing magiskboot binaries for all supported architectures."

    echo "[LOG] ✅ Release published: $tag_name"

    # Post to Telegram
    repository=$(git config --get remote.origin.url | sed 's/\.git$//')
    if [ -z "$repository" ]; then
        echo "[ERROR] Failed to get repository URL."
        exit 1
    fi
    version=$(cat magiskboot_version)
    if [ -z "$version" ]; then
        echo "[ERROR] Failed to read magiskboot_version."
        exit 1
    fi
    send_msg "*New magiskboot released!*\n\n[Download Release]($repository/releases/tag/$version)"
fi

# Cleanup
echo "[LOG] Cleaning up tempdir..."
rm -rf magisk_extracted
