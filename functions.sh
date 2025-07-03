#!/bin/bash

# send_msg <text>
send_msg() {
    local text=$(echo -e "$1")
    curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d "text=$text"
}
