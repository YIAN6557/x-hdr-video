#!/bin/zsh
# 查 X 有没有保留一条帖子里视频的 HDR。 Check whether X kept the HDR of a post's video.
# 用法 usage: zsh check_x_video.sh <帖子链接或 ID | post URL or ID>
# 做法：用公开的 fxtwitter 接口找到 X 实际播放的 mp4（每个清晰度），只下载开头 3 MB，用 ffprobe 读色彩标记。
# 需要 needs: curl, python3, ffprobe。帖子必须是公开的、还没删除。
set -e
[[ -n $1 ]] || { sed -n 2,5p $0; exit 1; }
ID=$(print -r -- "$1" | grep -oE '[0-9]{10,}' | head -1)
[[ -n $ID ]] || { echo "找不到帖子 ID / no post ID in: $1"; exit 1; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT

curl -sf -m 30 "https://api.fxtwitter.com/status/$ID" -o $W/t.json \
  || { echo "取不到这条帖子（可能已删除、不公开或接口暂时不可用）/ post not found"; exit 1; }
python3 -I - $W/t.json > $W/urls.txt <<'EOF'
import json, sys
t = json.load(open(sys.argv[1])).get("tweet") or {}
vids = [m for m in (t.get("media") or {}).get("all", []) if m.get("type") == "video"]
if vids:
    fm = [f for f in vids[0].get("formats", []) if f.get("container") == "mp4"]
    for f in sorted(fm, key=lambda f: f.get("bitrate") or 0):
        print(f["url"])
EOF
[[ -s $W/urls.txt ]] || { echo "这条帖子里没有视频 / no video in this post"; exit 1; }

echo "帖子 post $ID"
best=""
while read -r url; do
  curl -sf -m 60 -r 0-3000000 -o $W/v.mp4 "$url" || { echo "  下载失败 / download failed: $url"; continue; }
  IFS=, read -r w h trc prim <<< "$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,color_transfer,color_primaries -of csv=p=0 $W/v.mp4)"
  prim=${prim%%,*}
  printf "  %4sx%-4s  transfer=%-13s primaries=%s\n" $w $h "${trc:-none}" "${prim:-none}"
  best=$trc; short=$(( w < h ? w : h ))    # 最后一个是最高清晰度 / last one is the highest quality
done < $W/urls.txt

case $best in
  arib-std-b67) echo "✅ X 保留了 HDR（HLG）。 HLG_KEPT" ;;
  smpte2084)    echo "✅ X 保留了 HDR（PQ）。 PQ_KEPT" ;;
  bt709)        echo "⚠️  X 读到了 HDR，但把它转成了普通视频。多半是格式不对（HEVC、杜比视界、HDR10、iPhone 原生 HDR）。 TONE_MAPPED"
                echo "    改用 H.264 8 位 + HLG + BT.2020，标签写进码流。 Re-encode as H.264 8-bit HLG with VUI tags."
                if (( short <= 720 )); then
                  echo "    最高只有 ${short}p：如果是用 X app 发的，先看「数据节省」是不是开着，它会在手机上先把视频压成 720p 的普通视频。"
                  echo "    Only ${short}p: if posted from the X app, check that Data saver is off."
                fi ;;
  *)            echo "❌ 没有任何色彩标记：X 没有读文件里的色彩信息。 TAGS_DROPPED"
                echo "    如果上传的文件确实带 HLG 标记，多半是账号的问题，换格式也没用（见 README）。"
                echo "    If your upload really had HLG tags, this account is probably not getting HDR processing." ;;
esac
