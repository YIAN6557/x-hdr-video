#!/bin/zsh
# SDR 成片 → HDR（HLG + BT.2020）。输出的扩展名决定给谁：
#   .mov → 给 iPhone 本机看：HEVC 10 位，苹果封装（隔空投送后相册能按 HDR 播放）
#   .mp4 → 发 X：H.264 8 位 High，HLG + BT.2020（标签写进码流和容器），没有杜比视界。
#          X 只对这种格式保留 HDR；但有的账号 X 会丢掉所有色彩标记，换格式也没用，见 README。
# 需要：ffmpeg（带 libx264 / libx265）、python3；.mov 和最后的亮度检查只能在 macOS 上（avconvert、swift）。
#
# 用法：hdr.sh <输入 SDR 视频> <倍数> <输出.mov 或 .mp4> [配乐文件]
#   倍数：纸面白（SDR 的白）在手机上是界面白的几倍。1.5 / 2 / 3 / 4 / 5，5 是上限（HLG 峰值）。
#         也可以直接写尼特数（大于 50 当尼特）：331≈1.5 倍，441≈2 倍，662≈3 倍，882≈4 倍，1104≈5 倍。
#   配乐文件：给了就用它当音轨（AAC 256k）；不给就沿用输入视频自己的音轨（没有就无声）。
#   实拍素材只推高光：EXPAND="0.772 4.6" hdr.sh 素材.mp4 203 输出.mov
#         （203 尼特 = 纸面和界面白一样亮；Y 信号高于 0.772 的地方渐进提亮，到纯白时 4.6 倍；会先 deband 防天空色带）
#
# 做法：make_lut.py 生成 3D LUT → ffmpeg 在 16 位里套 LUT →
#       .mov：x265 CRF 14（no-sao，保细节）→ avconvert PresetPassthrough 只换苹果封装、不重新编码
#       .mp4：x264 CRF 16，High@4.2，码率封顶 50 Mbps
#       → 打印标记和苹果解码后的亮度。
# 不要用 avconvert 的 PresetHEVCHighestQuality：它会重新编码到约 11 Mbps，细节多的画面会糊。
set -e
T=${0:A:h}
IN=${1:A}; K=$2; OUT=${3:A}; AUD=${4:+${4:A}}
[[ -f $IN && -n $K && ( $OUT == *.mov || $OUT == *.mp4 ) ]] || { sed -n '2,22p' $0; exit 1; }
NITS=$(python3 -c "k = float('$K'); print(round(k if k > 50 else 220.8 * k))")
(( NITS <= 1104 )) || echo "注意：$NITS 尼特超过 1104（5 倍），亮部会被削平。"

W=$(mktemp -d); trap 'rm -rf $W' EXIT
if [[ $OUT == *.mp4 ]]; then
  PF=yuv420p
  VC=(-c:v libx264 -preset slow -crf 16 -profile:v high -level:v 4.2 -maxrate 50M -bufsize 62500k
      -x264-params "colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc")
else
  PF=yuv420p10le
  VC=(-c:v libx265 -preset medium -crf 14 -tag:v hvc1
      -x265-params "log-level=error:colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc:range=limited:no-sao=1")
fi
if [[ -n $EXPAND ]]; then
  python3 -I $T/make_lut.py $W/lut.cube $NITS --sat 1.05 --expand ${=EXPAND} >/dev/null
  DEBAND="deband=1thr=0.012:2thr=0.012:3thr=0.012:range=24:blur=1,"
else
  python3 -I $T/make_lut.py $W/lut.cube $NITS >/dev/null
  DEBAND=""
fi
print -r -- "[0:v]setparams=range=tv:colorspace=bt709:color_primaries=bt709:color_trc=bt709,scale=in_range=tv:in_color_matrix=bt709,format=gbrp16le,${DEBAND}lut3d=file=lut.cube:interp=tetrahedral,setparams=color_primaries=bt2020:color_trc=arib-std-b67,scale=out_color_matrix=bt2020:out_range=tv,format=$PF,setparams=range=tv:colorspace=bt2020nc:color_primaries=bt2020:color_trc=arib-std-b67[out]" > $W/graph.txt

if [[ -n $AUD ]]; then AI=(-i $AUD); AM=(-map 1:a -c:a aac -b:a 256k -shortest)
else AI=(); AM=(-map '0:a?' -c:a copy); fi
cd $W
echo "编码中：纸面白 = $NITS 尼特（约 $(python3 -c "print(round($NITS / 220.8, 1))") 倍界面白）"
ffmpeg -v error -y -i $IN $AI -/filter_complex graph.txt -map "[out]" $AM $VC -pix_fmt $PF \
  -color_primaries bt2020 -color_trc arib-std-b67 -colorspace bt2020nc -color_range tv \
  -movflags +faststart tmp.mp4
if [[ $OUT == *.mp4 ]]; then mv tmp.mp4 $OUT
else avconvert --source tmp.mp4 --preset PresetPassthrough --output $OUT --replace >/dev/null 2>&1; fi

echo "== $OUT"
ffprobe -v error -show_entries stream=codec_type,codec_name,profile,pix_fmt,color_transfer,color_primaries,duration -of csv=p=0 $OUT
ffprobe -v error -show_streams $OUT | grep -qi dovi && echo "注意：有杜比视界数据" || echo "没有杜比视界数据"
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $OUT)
for f in 0.25 0.5 0.9; do
  swift $T/edr_probe.swift $OUT $(python3 -c "print(round($D * $f, 2))") 2>/dev/null | grep -A1 "@" | tail -1
done
echo "（1.0 = 手机界面白；p50 是画面中间亮度，>1.0 是比界面白还亮的面积）"
