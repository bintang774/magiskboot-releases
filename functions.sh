#!/bin/bash

# send_msg <text>
send_msg() {
    curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=MarkdownV2" \
        -d "text=$1"
}
