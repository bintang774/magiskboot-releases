#!/bin/bash
# Copyright (C) https://github.com/bintang774 2025-forever

set -euo pipefail
source functions.sh

magiskrepo="https://api.github.com/repos/topjohnwu/Magisk/releases/latest"
RELEASE=0

download_magiskapk() {
    local magiskapk_url
    magiskapk_url=$(curl -s "$magiskrepo" | grep "browser_download_url" | grep -Eo 'https://.+Magisk-v[^"]+\.apk' | head -n 1)
    [ -z "$magiskapk_url" ] && echo "[ERROR] Failed to get Magisk APK URL" && exit 1
    wget "$magiskapk_url" -O magisk.zip
}

extract_magiskboot() {
    mkdir -p magisk_extracted
    unzip -q magisk.zip -d magisk_extracted || {
        echo "[ERROR] Failed to unzip"
        exit 1
    }

    declare -A arch_map=(
        ["arm64-v8a"]="arm64"
        ["armeabi-v7a"]="arm"
        ["x86"]="x86"
        ["x86_64"]="x86_64"
    )

    for dir in "${!arch_map[@]}"; do
        magiskboot_path="magisk_extracted/lib/$dir/libmagiskboot.so"
        if [ -f "$magiskboot_path" ]; then
            cp "$magiskboot_path" "magiskboot-${arch_map[$dir]}"
            echo "[LOG] Extracted magiskboot-${arch_map[$dir]}"
        else
            echo "[WARN] libmagiskboot.so not found for $dir"
        fi
    done
}

create_tag_name() {
    local latest_magiskversion
    latest_magiskversion=$(curl -s "$magiskrepo" | grep 'tag_name' | cut -d '"' -f4)
    echo "$latest_magiskversion" >magiskboot_version

    if [ -n "$(git status -s 2>/dev/null)" ]; then
        git config user.name "gacorprjkt-bot"
        git config user.email "gacorprjkt-bot@xnxx.com"
        git add magiskboot_version
        git commit -sm "magiskboot: Update to $latest_magiskversion"
        git push -u origin "$(git branch --show-current)"
        RELEASE=1
    else
        echo "[LOG] No changes to commit."
    fi
}

release_to_github() {
    if [ "$RELEASE" == "1" ]; then
        local tag_name
        tag_name=$(cat magiskboot_version)
        local release_name="MagiskBoot $tag_name"

        gh release create "$tag_name" \
            magiskboot/magiskboot-* \
            --title "$release_name" \
            --notes "Auto-generated release containing magiskboot binaries for all supported architectures."

        echo "[LOG] ✅ Release published: $tag_name"
    fi
}

post_to_telegram() {
    if [ "$RELEASE" == "1" ]; then
        local repository=$(git config --get remote.origin.url | sed 's/\.git$//')
        send_msg "*New magiskboot released!*\n[Download Release](${repository}/releases/tag/$(cat magiskboot_version))"
    fi
}

cleanup() {
    echo "[LOG] Cleaning up tempdir..."
    rm -rf "$tempdir"
}

# ========== MAIN ==========
mkdir -p magiskboot && cd magiskboot
download_magiskapk
extract_magiskboot

cd ..
create_tag_name
release_to_github
post_to_telegram
