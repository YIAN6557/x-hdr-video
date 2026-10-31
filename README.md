# 在 X 上发 HDR 视频：全部测试、正确编码和结论

X（推特）上有一类视频亮得"刺眼"：画面里的云、雪、阳光比手机界面的白色还亮很多。这是 HDR 视频。我们想自己做一条，在 X 上也这样发光，于是从拆解、编码、上传到下载 X 的文件逐个检查，前后试了 5 次，又查了 17 个账号的 130 多个视频文件，最后找到了确切原因。这个仓库是全部记录、得出的结论和用到的工具。

> **一句话结论**
>
> X 现在有**两套视频处理程序**：新的 **X-Qaptuur** 会读色彩信息，旧的 **Twitter-vork** 会把色彩标记全部丢掉。X 正在一个账号一个账号地把大家迁到新程序上。
> 你的号在新程序上：格式用 **H.264 8 位 + HLG + BT.2020，标签写进视频码流，不要杜比视界**，就能发 HDR。还在旧程序上：发什么、怎么发都不行，只能等。
> 查自己的号在哪套程序上，**不用发测试帖**：`zsh tools/check_account.sh 你的用户名`，看你以前发过的任何一条视频就知道。

数据截至 2026-11-01。X 没有公开说明过 HDR 视频的规则，下面都是从 X 实际下发的文件里查出来的，X 随时可能改。

## 结论

1. **X 会把每个视频都重新压一遍**（libx264，1080p 约 10 Mbps）。压完只有三种结果：
   - **保留 HLG**：手机按 HDR 播放，会发光。
   - **标成 bt709**：X 读到了 HDR，但把它转成了普通视频。颜色正常，不发光。
   - **什么标记都没有**：X 根本没读文件里的色彩信息。手机按普通视频播 HLG 信号，**颜色发灰发淡**，比普通版还难看。
2. **格式决定第 1 种还是第 2 种。** 在能用的账号上，只有 **H.264 8 位 HLG** 会被保留；杜比视界、HDR10、iPhone 自己拍的 HDR 都被转成了普通视频，HEVC 也一样（@banbudev 的经验）。@naundob 和 @banbudev 都是用**同一段素材**，只把格式换成 H.264 HLG，就从失败变成了成功。
3. **账号决定是不是第 3 种，原因是 X 的两套处理程序。** X 处理完的每个视频文件里都写着处理程序的名字。能用的账号是新程序 `X-Qaptuur`，不能用的账号（我们的号、@xiayitiaoAI、@vbar_io、@danielbeanpole、@gnarco）是旧程序 `Twitter-vork`。我们统计了 129 个能认出程序的文件：旧程序 79 个，**全部没有色彩标记**；新程序 50 个，24 个保留了 HLG、20 个转成 bt709、6 个没有标记（多半是原片本来就没有）。**所有保留了 HLG 的视频，都是新程序处理的。**
4. **不是运气。** 同一个账号、同一种格式，结果是固定的；成功和失败的帖子在时间上交错，也不是 X 在某个时间统一打开了这个功能。
5. **X 在一个账号一个账号地迁移。** 能用的账号以前也是旧程序：@naundob 10-04 之后、@banbudev 10-12 之后、@SpaceX 10-20 到 10-25 之间、@hi_personality 10-21 到 10-22 之间换到了新程序。到 10 月底，@OpenAI、@MKBHD、@BBCWorld 这样的大号也还在旧程序上；我们的号是会员、在美国，也还在旧程序上。所以跟粉丝数、会员、认证、地区都没关系，什么时候迁到哪个号，只有 X 知道。网页版也没有任何 HDR 开关：我们登录后看了全部 1513 个功能开关和上传代码，上传时只发文件大小、类型、时长，没有提 HDR。
6. **没法把 HDR "固定"在画面里。** 视频里的像素只是数字，"按多亮显示"是靠色彩标记告诉手机的。X 重新压缩时丢掉标记，画面数字原样不动，手机就按普通视频播，最亮只能到界面白。
7. **存进 iPhone 相册要用 `.mov`。** H.264 8 位 HLG 存成 `.mp4` 隔空投送到相册，不按 HDR 播放；同样的编码存成 `.mov`，相册就按 HDR 播放（HEVC 10 位 `.mov` 也可以）。想从 iPhone 的 X app 发，就用 H.264 8 位 HLG 的 `.mov`：相册认它是 HDR，编码也是 X 要的。按目前的测试，HEVC 发到 X 会被转成普通视频。
8. **上传方式救不了不能用的账号。** 第 5 次我们按网上流传的做法，把 H.264 8 位 HLG `.mov` 存进相册（相册里已经按 HDR 播放），用 X app 发，X 发出来的文件还是没有任何色彩标记，和电脑浏览器发的第 3 次一样。
9. **X app 的「数据节省」模式也会让 HDR 失败，但不是我们的原因。** 打开后，X app 看起来会先在手机上把视频压成 720p 的普通视频再上传：X 下发的最高只有 720p，标记是 bt709（@naundob 的测试）。我们的号本来就关着，失败的样子也不一样：有 1080p、完全没有标记，用电脑浏览器发也一样。

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

**第一步不用发测试帖。** 只要你的号最近发过视频（普通视频也行）：

```bash
zsh tools/check_account.sh 你的用户名
```

- `ON_NEW_PIPELINE`：最新的视频是新程序 X-Qaptuur 处理的，你的号能发 HDR。
- `ON_LEGACY_PIPELINE`：还在旧程序 Twitter-vork 上，现在发 HDR 只会颜色发灰。过一段时间再查。

在新程序上的话，正式发之前可以再用一条测试帖确认格式：

1. 用上面的方法做一个几秒的测试片，电脑浏览器发一条帖子。
2. 马上运行：

   ```bash
   zsh tools/check_x_video.sh https://x.com/你的账号/status/帖子ID
   ```

3. 看最后一行：
   - `HLG_KEPT`：你的号能发 HDR 视频。删掉测试帖，正式发。
   - `TONE_MAPPED`：X 读到了 HDR，但格式不对。检查是不是 H.264、标签是不是写进了码流。如果最高只有 720p，又是用 X app 发的，先看 X app 的「数据节省」是不是开着。
   - `TAGS_DROPPED`：X 没读色彩信息。脚本会同时显示是哪套程序处理的；是 `Twitter-vork`，就是你的号还在旧程序上，**马上删帖**（颜色会发灰），改发普通版。

两个脚本都通过公开的 [fxtwitter](https://github.com/FixTweet/FxTwitter) 接口找到 X 实际播放的文件，只下载开头一小段（3 MB / 600 KB），读色彩标记和处理程序的名字。帖子和账号必须是公开的。

## 文件

| 文件 | 做什么 |
|---|---|
| [docs/01_尝试记录.md](docs/01_尝试记录.md) | 从拆解参考片、5 次上传测试，到找到确切原因，每一步做了什么、结果怎样 |
| [docs/02_X怎么处理视频.md](docs/02_X怎么处理视频.md) | X 的转码方式、两套处理程序（确切原因）、账号对照表 |
| [docs/03_编码方式.md](docs/03_编码方式.md) | 编码参数、PQ 转 HLG、亮度、检查方法、AI 提示词 |
| [tools/check_account.sh](tools/check_account.sh) | 查一个账号现在在哪套处理程序上，不用发测试帖 |
| [tools/check_x_video.sh](tools/check_x_video.sh) | 查一条帖子的视频在 X 上还是不是 HDR、是哪套程序处理的 |
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
- 处理程序的名字 "Twitter-vork" 最早是 [@gnarco](https://x.com/gnarco/status/2116555063523152028) 在讨论里注意到的。
- 失败的对照来自 [@xiayitiaoAI](https://x.com/xiayitiaoAI/status/2116393051564421218)、[@photonsynth](https://x.com/photonsynth/status/2116392277744513166)、[@vbar_io](https://x.com/vbar_io/status/2116302601339736382)、[@danielbeanpole](https://x.com/danielbeanpole/status/2116384883123880175) 公开的测试。
- 测试和整理：[Eian（@EianLu）](https://x.com/EianLu) 和 Claude。

如果你测出了不一样的结果（尤其是你的号从 Twitter-vork 换到了 X-Qaptuur，或者看出了 X 迁移账号的规律），欢迎开 issue。

## 许可

代码和文档用 [MIT](LICENSE) 许可。

<details>
<summary>English</summary>

### HDR video on X: every test, the right encoding, and what we found

Some videos on X glow: clouds and sunlight look brighter than the app's white UI. That is HDR (HLG) video. We tried to post our own, failed five times, then checked 130+ files X actually serves from 17 accounts and found the exact cause. This repo has the full log, the analysis and the tools.

**Root cause.** X currently runs two video pipelines. Every MP4 it serves names the one that made it: the new `X-Qaptuur muxer` (x264 core 165) reads color metadata; the legacy `Twitter-vork muxer` (x264 core 164) drops every color tag. X is moving accounts to the new pipeline one by one. If your account is still on Twitter-vork, nothing you upload will stay HDR. Check without posting a test: `zsh tools/check_account.sh <username>` reads your recent videos.

**Short answer.** On the new pipeline, encode as **H.264 8-bit 4:2:0, HLG (arib-std-b67) + BT.2020, tags in the H.264 bitstream (VUI) as well as the container, no Dolby Vision**, and upload from a **desktop browser**. Then post a short test and run `tools/check_x_video.sh <post URL>`. If your master is PQ / HDR10 (`smpte2084`), convert it to HLG first (`zscale=t=arib-std-b67:p=bt2020:m=bt2020nc:r=tv:npl=1000:d=error_diffusion,format=yuv420p`, see `docs/03`); X tone-maps PQ uploads to SDR.

**What we found (as of 2026-11-01):**

1. X re-encodes every upload with libx264 (1080p: CRF 23, ~10 Mbps cap). The output is one of three things: HLG kept (glows); tagged bt709 (X saw the HDR and tone-mapped it to SDR); or no color tags at all (X ignored the metadata, so the HLG signal plays as SDR and looks washed out).
2. Format decides between the first two. On working accounts only H.264 8-bit HLG is kept; HEVC, Dolby Vision, HDR10 and native iPhone HDR come back as bt709. @naundob and @banbudev turned a failure into a success with the same clip, only changing the format.
3. The pipeline decides the third. Of 129 files whose pipeline we could read, all 79 from Twitter-vork had no color tags; of 50 from X-Qaptuur, 24 kept HLG, 20 were bt709 and 6 untagged (likely untagged sources). Every HLG file came from X-Qaptuur. Working accounts are on X-Qaptuur; ours, @xiayitiaoAI, @vbar_io, @danielbeanpole and @gnarco are on Twitter-vork.
4. It is not luck: results are consistent per account and format, and successes and failures are interleaved in time.
5. It is a per-account migration. Working accounts were on Twitter-vork until October (@naundob after 10-04, @banbudev after 10-12, @SpaceX between 10-20 and 10-25, @hi_personality between 10-21 and 10-22). @OpenAI, @MKBHD and @BBCWorld were still on it at the end of October, and so is our Premium, US-based account, so followers, subscription, verification and region don't explain it. The web client has no HDR switch: none of its 1,513 feature switches mention HDR, and an upload only sends size, type and duration.
6. You can't "bake" HDR into the pixels. Brightness comes from the color tags; when X drops them, the pixel values stay the same and the player treats them as SDR.
7. For the iPhone Photos app the container matters: H.264 8-bit HLG plays as HDR when saved as `.mov`, not as `.mp4` (HEVC 10-bit `.mov` also works). To post from the X iOS app, use an H.264 8-bit HLG `.mov`. X tone-maps HEVC to SDR.
8. The upload path does not rescue an affected account: our fifth test (H.264 8-bit HLG `.mov`, already shown as HDR in Photos, posted from the X app) came back untagged, exactly like the desktop-browser upload.
9. The X app's Data saver also breaks HDR, but differently: the app seems to re-encode the video on the phone first, so X serves at most 720p, tagged bt709 (@naundob's test). Our account had it off, and our failure looks different (1080p, no tags at all, same from desktop Chrome).

**Files:** `docs/` (in Chinese) has the attempt log, the analysis with the pipeline evidence, and the encoding guide. `tools/check_account.sh` tells which pipeline an account is on; `tools/check_x_video.sh` checks a post; `tools/hdr.sh` turns an SDR video into HLG (`.mp4` for X, `.mov` for iPhone); the other tools measure brightness. Requires ffmpeg (libx264/libx265), python3 and curl; the `.mov` output and Swift tools need macOS.

Found a different result? Please open an issue. MIT licensed.

</details>
