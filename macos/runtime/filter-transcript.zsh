#!/bin/zsh
set -u

text=$(cat)

# Whisper may emit learned video/subtitle boilerplate when the input is silent
# or contains only weak background noise. Keep this list deliberately narrow.
case "$text" in
  *"请不吝点赞订阅转发打赏支持明镜与点点栏目"*|*"明镜需要您的支持 欢迎订阅明镜"*|*"中文字幕志愿者 杨茜茜"*)
    exit 0
    ;;
esac

print -rn -- "$text"
