#!/usr/bin/env bash
# Convert .mkv (and other containers iPad can't play) to .mp4 next to the original.
# Video is copied as-is (HEVC gets the hvc1 tag Apple needs); non-AAC audio becomes AAC stereo;
# the first text subtitle track is extracted to a .srt with the same name.
#
# Usage:  tools/convert-mkv.sh <file-or-folder> [...]
#         CONVERT_SECONDS=30 tools/convert-mkv.sh x.mkv   # only the first 30 s, for testing
set -euo pipefail

command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null || { echo "需要 ffmpeg：brew install ffmpeg" >&2; exit 1; }
[[ $# -gt 0 ]] || { echo "用法：tools/convert-mkv.sh <文件或文件夹> ..." >&2; exit 1; }

limit=()
[[ -n "${CONVERT_SECONDS:-}" ]] && limit=(-t "$CONVERT_SECONDS")
ok=0; skipped=0; failed=0

convert_one() {
  local in="$1"
  local base="${in%.*}" out="${in%.*}.mp4" srt="${in%.*}.srt"
  if [[ -e "$out" ]]; then echo "跳过（已有 mp4）：$out"; skipped=$((skipped + 1)); return; fi

  local vcodec acodec pixfmt
  vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$in" | head -1)
  pixfmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$in" | head -1)
  acodec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$in" | head -1)

  local vargs aargs
  case "$vcodec" in
    h264) if [[ "$pixfmt" == *10* ]]; then vargs=(-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p); else vargs=(-c:v copy); fi ;;
    hevc) vargs=(-c:v copy -tag:v hvc1) ;;
    *)    vargs=(-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p) ;;
  esac
  if [[ "$acodec" == "aac" ]]; then aargs=(-c:a copy); else aargs=(-c:a aac -b:a 160k -ac 2); fi

  echo "转换：$(basename "$in")  （视频 $vcodec → ${vargs[1]}，音频 ${acodec:-无} → ${aargs[1]}）"
  # ${limit[@]+...}: macOS bash 3.2 treats an empty array as unbound under set -u
  if ffmpeg -nostdin -hide_banner -loglevel error -stats -y -i "$in" ${limit[@]+"${limit[@]}"} \
       -map 0:v:0 -map '0:a:0?' "${vargs[@]}" "${aargs[@]}" -movflags +faststart "$base.part.mp4"; then
    mv "$base.part.mp4" "$out"; ok=$((ok + 1))
  else
    rm -f "$base.part.mp4"; echo "  失败：$in" >&2; failed=$((failed + 1)); return
  fi

  if [[ ! -e "$srt" ]]; then
    local sidx
    sidx=$(ffprobe -v error -select_streams s -show_entries stream=index,codec_name -of csv=p=0 "$in" \
           | awk -F, '$2 ~ /subrip|ass|ssa|mov_text|webvtt|text/ {print $1; exit}')
    if [[ -n "$sidx" ]] && ffmpeg -nostdin -loglevel error -y -i "$in" -map "0:$sidx" "$srt"; then
      echo "  抽出字幕：$(basename "$srt")"
    fi
  fi
}

for arg in "$@"; do
  if [[ -d "$arg" ]]; then
    while IFS= read -r -d '' f; do convert_one "$f"; done \
      < <(find "$arg" \( -type f -o -type l \) \( -iname '*.mkv' -o -iname '*.avi' -o -iname '*.webm' -o -iname '*.ts' \) -print0 | sort -z)
  elif [[ -f "$arg" ]]; then
    convert_one "$arg"
  else
    echo "找不到：$arg" >&2; failed=$((failed + 1))
  fi
done
echo "完成：转换 $ok 个，跳过 $skipped 个，失败 $failed 个。"
