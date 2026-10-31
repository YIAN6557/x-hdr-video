"""SDR (BT.709, BT.1886) -> HLG (BT.2020) 3D LUT.

usage: make_lut.py out.cube [white_nits] [--sat 1.10] [--expand s0 gmax]
  white_nits = display nits for SDR white (1.0); HLG peak is 1000 nits.
  203  -> SDR white = HLG reference white (75%), the paper matches X's UI white
  1104 -> the paper (linear ~0.906) lands on the HLG peak ("max bright")
  --expand s0 gmax: highlight expansion for real footage. Pixels whose BT.709 luma signal is above s0
                    (0-1, full range after limited→full) get brighter with an ease-in, up to gmax times at 1.0;
                    hue is kept. Everything below s0 stays exactly as the plain white_nits mapping.
"""
import math
import sys


def _opt(name, n):
    if name not in sys.argv:
        return None
    i = sys.argv.index(name)
    vals = [float(v) for v in sys.argv[i + 1:i + 1 + n]]
    del sys.argv[i:i + 1 + n]
    return vals


N = 65
SAT = (_opt("--sat", 1) or [1.10])[0]   # saturation in linear light (1.10 = mild boost)
EXPAND = _opt("--expand", 2)
GAIN = float(sys.argv[2]) / 1000 if len(sys.argv) > 2 else 0.203
GAMMA = 1.2         # HLG system gamma at 1000 nits
A, B, C = 0.17883277, 0.28466892, 0.55991073

M709_2020 = (
    (0.6274, 0.3293, 0.0433),
    (0.0691, 0.9195, 0.0114),
    (0.0164, 0.0880, 0.8956),
)


def hlg_oetf(e):
    e = min(max(e, 0.0), 1.0)
    return math.sqrt(3 * e) if e <= 1 / 12 else A * math.log(12 * e - B) + C


def convert(r, g, b):
    gain = GAIN
    if EXPAND:
        s0, gmax = EXPAND
        t = min(max((0.2126 * r + 0.7152 * g + 0.0722 * b - s0) / (1 - s0), 0.0), 1.0)
        gain *= 1 + (gmax - 1) * t * t
    # BT.1886 decode (zero black level)
    r, g, b = r ** 2.4, g ** 2.4, b ** 2.4
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    r, g, b = (max(y + SAT * (v - y), 0.0) for v in (r, g, b))
    r, g, b = (sum(m * v for m, v in zip(row, (r, g, b))) for row in M709_2020)
    r, g, b = r * gain, g * gain, b * gain
    # hue-preserving clip at the peak
    peak = max(r, g, b)
    if peak > 1.0:
        r, g, b = r / peak, g / peak, b / peak
    # inverse HLG OOTF (display light -> scene light), then OETF
    yd = 0.2627 * r + 0.6780 * g + 0.0593 * b
    k = yd ** ((1 - GAMMA) / GAMMA) if yd > 1e-9 else 0.0
    return tuple(hlg_oetf(v * k) for v in (r, g, b))


def main(path):
    with open(path, "w") as f:
        f.write(f"LUT_3D_SIZE {N}\n")
        for bi in range(N):
            for gi in range(N):
                for ri in range(N):
                    out = convert(ri / (N - 1), gi / (N - 1), bi / (N - 1))
                    f.write("%.6f %.6f %.6f\n" % out)


if __name__ == "__main__":
    for v in (0.0, 0.18, 0.5, 0.75, 0.96, 1.0):
        print("SDR %.2f -> HLG %.3f" % (v, convert(v, v, v)[0]))
    main(sys.argv[1])
