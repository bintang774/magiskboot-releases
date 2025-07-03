#!/bin/bash
# Copyright (C) https://github.com/bintang774 2025-forever

set -euo pipefail
source functions.sh
magiskrepo="https://api.github.com/repos/topjohnwu/Magisk/releases/latest"
RELEASE=0

# Create directory and change to it
mkdir -p magiskboot && cd magiskboot

# Download Magisk APK
magiskapk_url=$(curl -s "$magiskrepo" | grep "browser_download_url" | grep -Eo 'https://.+Magisk-v[^"]+\.apk' | head -n 1)
if [ -z "$magiskapk_url" ]; then
    echo "[ERROR] Failed to get Magisk APK URL"
    exit 1
fi
wget -q "$magiskapk_url" -O magisk.zip

# Extract magiskboot
mkdir -p magisk_extracted
unzip -q magisk.zip -d magisk_extracted

# Define architecture map
declare -A arch_map=(
    ["arm64-v8a"]="arm64"
    ["armeabi-v7a"]="arm"
    ["x86"]="x86"
    ["x86_64"]="x86_64"
)

# Extract magiskboot for each architecture
for arch in "${!arch_map[@]}"; do
    magiskboot_path="magisk_extracted/lib/$arch/libmagiskboot.so"
    if [ -f "$magiskboot_path" ]; then
        cp "$magiskboot_path" "magiskboot-${arch_map[$arch]}"
        echo "[LOG] Extracted magiskboot-${arch_map[$arch]}"
    else
        echo "[WARN] libmagiskboot.so not found for $arch"
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

# Create GitHub release and post to Telegram
if [ "$RELEASE" == "1" ]; then
    tag_name=$(cat magiskboot_version)
    release_name="MagiskBoot $tag_name"

    gh release create "$tag_name" \
        magiskboot/magiskboot-* \
        --title "$release_name" \
        --notes "Auto-generated release containing magiskboot binaries for all supported architectures."

    echo "[LOG] ✅ Release published: $tag_name"

    repository=$(git config --get remote.origin.url | sed 's/\.git$//')
    message="New magiskboot version detected: *$tag_name*\nDownload: [Here]($repository/releases/tag/$tag_name)"
    send_msg "$message"
fi
