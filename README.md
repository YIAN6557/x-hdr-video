# 在 X 上发 HDR 视频：全部测试、正确编码和结论

X（推特）上有一类视频亮得"刺眼"：画面里的云、雪、阳光比手机界面的白色还亮很多。这是 HDR 视频。我们想自己做一条，在 X 上也这样发光，于是从拆解、编码、上传到下载 X 的文件逐个检查，前后试了 5 次，还查了 8 个账号在 X 上的视频。这个仓库是全部记录、得出的结论和用到的工具。

> **一句话结论**
>
> 格式必须是 **H.264 8 位 + HLG + BT.2020，标签写进视频码流，不要杜比视界**，用**电脑浏览器**上传。
> 但这只在"X 会读色彩信息"的账号上有效。在另一些账号上，X 会把色彩标记全部丢掉，换什么格式、怎么上传都没用。
> 发正式内容前，先发一条测试帖，用 [`tools/check_x_video.sh`](tools/check_x_video.sh) 查一下自己的号。

数据截至 2026-10-31。X 没有公开说明过 HDR 视频的规则，下面都是从 X 实际下发的文件里查出来的，X 随时可能改。

## 结论

1. **X 会把每个视频都重新压一遍**（libx264，1080p 约 10 Mbps）。压完只有三种结果：
   - **保留 HLG**：手机按 HDR 播放，会发光。
   - **标成 bt709**：X 读到了 HDR，但把它转成了普通视频。颜色正常，不发光。
   - **什么标记都没有**：X 根本没读文件里的色彩信息。手机按普通视频播 HLG 信号，**颜色发灰发淡**，比普通版还难看。
2. **格式决定第 1 种还是第 2 种。** 在能用的账号上，只有 **H.264 8 位 HLG** 会被保留；杜比视界、HDR10、iPhone 自己拍的 HDR 都被转成了普通视频，HEVC 也一样（@banbudev 的经验）。@naundob 和 @banbudev 都是用**同一段素材**，只把格式换成 H.264 HLG，就从失败变成了成功。
3. **账号决定是不是第 3 种。** 能用的账号每次都成功（@banbudev 8/8、@hi_personality 9/9），不能用的账号每次都是"没有标记"（我们的号、@xiayitiaoAI、@photonsynth、@vbar_io、@danielbeanpole）。@xiayitiaoAI 把一个**在别人号上能发光的 X 文件**原样重新上传，到他的号上也变成了普通视频。
4. **不是运气。** 同一个账号、同一种格式，结果是固定的；成功和失败的帖子在时间上交错，也不是 X 在某个时间统一打开了这个功能。
5. **跟账号的什么有关，还不知道。** 可能是 X 的灰度测试、会员等级或别的设置。被认证（蓝标）不是关键：成功和失败的账号里都有认证账号。成功的有德语账号，也有中文账号，失败的也是两种都有，所以"按地区"的可能性不大，但不能排除。
6. **没法把 HDR "固定"在画面里。** 视频里的像素只是数字，"按多亮显示"是靠色彩标记告诉手机的。X 重新压缩时丢掉标记，画面数字原样不动，手机就按普通视频播，最亮只能到界面白。
7. **存进 iPhone 相册要用 `.mov`。** H.264 8 位 HLG 存成 `.mp4` 隔空投送到相册，不按 HDR 播放；同样的编码存成 `.mov`，相册就按 HDR 播放（HEVC 10 位 `.mov` 也可以）。想从 iPhone 的 X app 发，就用 H.264 8 位 HLG 的 `.mov`：相册认它是 HDR，编码也是 X 要的。按目前的测试，HEVC 发到 X 会被转成普通视频。
8. **上传方式救不了不能用的账号。** 第 5 次我们按网上流传的做法，把 H.264 8 位 HLG `.mov` 存进相册（相册里已经按 HDR 播放），用 X app 发，X 发出来的文件还是没有任何色彩标记，和电脑浏览器发的第 3 次一样。

完整过程见 [docs/01_尝试记录.md](docs/01_尝试记录.md)，证据和分析见 [docs/02_X怎么处理视频.md](docs/02_X怎么处理视频.md)。

## 正确的编码方式

| | 发 X | 自己在 iPhone 上看 |
|---|---|---|
| 编码 | **H.264**（High） | HEVC（H.265），标签 hvc1 |
| 位深 | **8 位**，yuv420p | 10 位 |
| 曲线 / 色域 | **HLG**（arib-std-b67）/ **BT.2020** | HLG / BT.2020 |
| 标签写在哪 | **码流（VUI）和容器都写** | 码流和容器都写 |
| 杜比视界 | **不要** | 不要 |
| 文件 | `.mp4` | `.mov` |
| 怎么传 | **电脑浏览器打开 x.com 直接传**，不要裁剪、不要编辑 | 隔空投送到相册 |

已经有 HLG 母版（比如达芬奇导出的 HEVC 10 位 HLG），转成发 X 的格式：

```bash
ffmpeg -i 母版_HLG.mov -c:v libx264 -preset slow -crf 18 -profile:v high -pix_fmt yuv420p \
  -x264-params "colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc" \
  -color_primaries bt2020 -color_trc arib-std-b67 -colorspace bt2020nc -color_range tv \
  -c:a aac -b:a 192k -movflags +faststart 发X用.mp4
```

`-x264-params` 那一行最重要：它把标签写进码流。只用 `-c copy` 改容器里的标签，X 会忽略。

母版是 PQ / HDR10（ffprobe 显示 `smpte2084`，达芬奇、LumaFusion 的 HDR 导出常见），要先转成 HLG，直接发会被 X 转成普通视频。命令见 [docs/03_编码方式.md](docs/03_编码方式.md) 的「方法 A2」。

只有普通（SDR）成片，用一条命令直接做出 HDR 版：

```bash
zsh tools/hdr.sh 普通版.mp4 3 发X用.mp4          # 3 = 白色在手机上是界面白的 3 倍，最高 5
zsh tools/hdr.sh 普通版.mp4 3 iPhone本机看.mov   # 同一条命令，输出写 .mov 就是 iPhone 版
```

更多细节（亮度怎么定、检查方法、可以直接发给 AI 的提示词）见 [docs/03_编码方式.md](docs/03_编码方式.md)。

## 先测你的账号

1. 用上面的方法做一个几秒的测试片，电脑浏览器发一条帖子。
2. 马上运行：

   ```bash
   zsh tools/check_x_video.sh https://x.com/你的账号/status/帖子ID
   ```

3. 看最后一行：
   - `HLG_KEPT`：你的号能发 HDR 视频。删掉测试帖，正式发。
   - `TONE_MAPPED`：X 读到了 HDR，但格式不对。检查是不是 H.264、标签是不是写进了码流。
   - `TAGS_DROPPED`：X 没读色彩信息。如果文件没问题，就是账号的原因，**马上删帖**（颜色会发灰），改发普通版。

脚本通过公开的 [fxtwitter](https://github.com/FixTweet/FxTwitter) 接口找到 X 实际播放的文件，只下载开头 3 MB，用 ffprobe 读标记。帖子必须公开、没删。

## 文件

| 文件 | 做什么 |
|---|---|
| [docs/01_尝试记录.md](docs/01_尝试记录.md) | 从拆解参考片到 4 次上传测试，每一步做了什么、结果怎样 |
| [docs/02_X怎么处理视频.md](docs/02_X怎么处理视频.md) | X 的转码方式、8 个账号的对照表、为什么判断是账号的问题 |
| [docs/03_编码方式.md](docs/03_编码方式.md) | 编码参数、PQ 转 HLG、亮度、检查方法、AI 提示词 |
| [tools/check_x_video.sh](tools/check_x_video.sh) | 查一条帖子的视频在 X 上还是不是 HDR |
| [tools/hdr.sh](tools/hdr.sh) | 普通视频 → HDR，一条命令（`.mp4` 发 X，`.mov` iPhone 本机看） |
| [tools/make_lut.py](tools/make_lut.py) | 生成 SDR → HLG 的 3D LUT（hdr.sh 会调用） |
| [tools/edr_probe.swift](tools/edr_probe.swift) | 用苹果的解码器读一帧，报告亮度（1.0 = 界面白） |
| [tools/check_hdr.swift](tools/check_hdr.swift) | 问苹果的系统：这个文件算不算 HDR |
| [tools/luma_stats.py](tools/luma_stats.py) | 统计亮度分布（直接读原始 Y 平面，要 numpy，按 1920×1080 写的） |

需要：ffmpeg（带 libx264、libx265）、python3、curl。`.mov` 输出和两个 swift 工具只能在 macOS 上用。

## 来源和致谢

- 参考片：[@hi_personality](https://x.com/hi_personality) 的 HDR 视频。
- 格式要求最早来自 [@naundob](https://x.com/naundob/status/2116489655302730201) 的回复和他自己的 5 次测试。
- 能用的上传方法来自 [@banbudev](https://x.com/banbudev/status/2116391249645080866) 的分享。
- 失败的对照来自 [@xiayitiaoAI](https://x.com/xiayitiaoAI/status/2116393051564421218)、[@photonsynth](https://x.com/photonsynth/status/2116392277744513166)、[@vbar_io](https://x.com/vbar_io/status/2116302601339736382)、[@danielbeanpole](https://x.com/danielbeanpole/status/2116384883123880175) 公开的测试。
- 测试和整理：[Eian（@EianLu）](https://x.com/EianLu) 和 Claude。

如果你测出了不一样的结果（尤其是失败的账号后来能用了，或者找到了账号之间的区别），欢迎开 issue。

## 许可

代码和文档用 [MIT](LICENSE) 许可。

<details>
<summary>English</summary>

### HDR video on X: every test, the right encoding, and what we found

Some videos on X glow: clouds and sunlight look brighter than the app's white UI. That is HDR (HLG) video. We tried to post our own, failed five times, and then checked the files X actually serves for 8 accounts. This repo has the full log, the analysis and the tools.

**Short answer.** Encode as **H.264 8-bit 4:2:0, HLG (arib-std-b67) + BT.2020, tags in the H.264 bitstream (VUI) as well as the container, no Dolby Vision**, and upload from a **desktop browser**. This only works on accounts where X reads color metadata. On other accounts X drops all color tags, whatever you upload. Post a short test first and run `tools/check_x_video.sh <post URL>`. If your master is PQ / HDR10 (`smpte2084`), convert it to HLG first (`zscale=t=arib-std-b67:p=bt2020:m=bt2020nc:r=tv:npl=1000:d=error_diffusion,format=yuv420p`, see `docs/03`); X tone-maps PQ uploads to SDR.

**What we found (as of 2026-10-31):**

1. X re-encodes every upload with libx264 (1080p: CRF 23, ~10 Mbps cap). The output is one of three things: HLG kept (glows); tagged bt709 (X saw the HDR and tone-mapped it to SDR); or no color tags at all (X ignored the metadata, so the HLG signal plays as SDR and looks washed out).
2. Format decides between the first two. On working accounts only H.264 8-bit HLG is kept; HEVC, Dolby Vision, HDR10 and native iPhone HDR come back as bt709. @naundob and @banbudev turned a failure into a success with the same clip, only changing the format.
3. The account decides the third. Working accounts succeed every time (@banbudev 8/8, @hi_personality 9/9). Other accounts (ours, @xiayitiaoAI, @photonsynth, @vbar_io, @danielbeanpole) always come back untagged. @xiayitiaoAI reports re-uploading a glowing file served by X from another account, unchanged, and it lost HDR on his account.
4. It is not luck: results are consistent per account and format, and successes and failures are interleaved in time.
5. We don't know what about the account matters (a staged rollout, subscription tier, a setting). Verification (blue check) and region don't seem to explain it.
6. You can't "bake" HDR into the pixels. Brightness comes from the color tags; when X drops them, the pixel values stay the same and the player treats them as SDR.
7. For the iPhone Photos app the container matters: H.264 8-bit HLG plays as HDR when saved as `.mov`, not as `.mp4` (HEVC 10-bit `.mov` also works). To post from the X iOS app, use an H.264 8-bit HLG `.mov`. X tone-maps HEVC to SDR.
8. The upload path does not rescue an affected account: our fifth test (H.264 8-bit HLG `.mov`, already shown as HDR in Photos, posted from the X app) came back untagged, exactly like the desktop-browser upload.

**Files:** `docs/` (in Chinese) has the attempt log, the analysis with the 8-account table, and the encoding guide. `tools/check_x_video.sh` checks a post; `tools/hdr.sh` turns an SDR video into HLG (`.mp4` for X, `.mov` for iPhone); the other tools measure brightness. Requires ffmpeg (libx264/libx265), python3 and curl; the `.mov` output and Swift tools need macOS.

Found a different result? Please open an issue. MIT licensed.

</details>
