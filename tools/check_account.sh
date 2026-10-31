#!/bin/zsh
# 查一个 X 账号现在用的是哪套视频处理程序。 Which X video pipeline is an account on?
# 用法 usage: zsh check_account.sh <用户名 | username> [条数 count, 默认 5]
# 做法：用公开的 fxtwitter 接口找这个账号最近发的视频，每条只下载开头 600 KB，读文件里 X 处理程序的名字：
#   X-Qaptuur（新）    会读上传文件的色彩信息：H.264 8 位 HLG 能保留 HDR。
#   Twitter-vork（旧） 会丢掉所有色彩标记，发什么都不会是 HDR。
# 不需要发 HDR 测试帖：随便一条普通视频就能看出来。 Any normal video post works; no HDR test post needed.
# 需要 needs: curl, python3。账号要公开，最近要发过视频。
set -e
[[ -n $1 ]] || { sed -n 2,8p $0; exit 1; }
U=${1#@}; N=${2:-5}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
curl -sf -m 30 "https://api.fxtwitter.com/2/profile/$U/media" -o $W/m.json \
  || { echo "取不到这个账号（可能不存在、不公开或接口暂时不可用）/ account not found"; exit 1; }
python3 -I - $W/m.json $U $N > $W/list.txt <<'PY'
import json, sys
from datetime import datetime
d = json.load(open(sys.argv[1])); user = sys.argv[2].lower(); n = int(sys.argv[3]); k = 0
for s in d.get("results") or []:
    if s["author"]["screen_name"].lower() != user:
        continue
    for m in (s.get("media") or {}).get("all") or []:
        fm = sorted([f for f in m.get("formats", []) if f.get("container") == "mp4"], key=lambda f: f.get("bitrate") or 0)
        if m.get("type") == "video" and fm:
            t = datetime.strptime(s["created_at"], "%a %b %d %H:%M:%S %z %Y").strftime("%Y-%m-%d")
            print(t, s["id"], fm[-1]["url"]); k += 1
            break
    if k >= n:
        break
PY
[[ -s $W/list.txt ]] || { echo "最近没有找到这个账号发的视频 / no recent videos"; exit 1; }
echo "@$U 最近的视频 recent videos:"
newest=""
while read -r day id url; do
  curl -sf -m 60 -r 0-600000 -o $W/v.mp4 "$url" || { echo "  $day  $id  下载失败 / download failed"; continue; }
  p=$(LC_ALL=C grep -aoE 'X-Qaptuur|Twitter-vork' $W/v.mp4 | head -1)
  echo "  $day  $id  ${p:-unknown}"
  [[ -n $newest ]] || newest=$p
done < $W/list.txt
case $newest in
  X-Qaptuur)    echo "✅ 最新的视频走的是新程序 X-Qaptuur：这个账号可以发 HDR（H.264 8 位 HLG）。 ON_NEW_PIPELINE" ;;
  Twitter-vork) echo "❌ 最新的视频走的是旧程序 Twitter-vork：现在发 HDR 会丢掉所有色彩标记，只能等 X 迁移。 ON_LEGACY_PIPELINE" ;;
  *)            echo "？没认出处理程序。 UNKNOWN" ;;
esac
