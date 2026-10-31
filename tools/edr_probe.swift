// Decode one frame the way Apple does and report its brightness, where 1.0 = SDR / UI white.
// With out.png + headroom it also writes a simulated phone view: the frame sits in a border of
// UI white drawn at 1/headroom, so anything brighter than the UI shows up as brighter than the border.
// usage: swift edr_probe.swift <video> <seconds> [out.png headroom]
import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!

func decode(_ path: String, at sec: Double) async throws -> CVPixelBuffer {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let track = try await asset.loadTracks(withMediaType: .video).first!
    let reader = try AVAssetReader(asset: asset)
    let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange])
    reader.add(out)
    reader.timeRange = CMTimeRange(start: CMTime(seconds: sec, preferredTimescale: 600),
                                   duration: CMTime(seconds: 0.1, preferredTimescale: 600))
    reader.startReading()
    guard let sb = out.copyNextSampleBuffer(), let pb = CMSampleBufferGetImageBuffer(sb) else {
        throw NSError(domain: "probe", code: 1, userInfo: [NSLocalizedDescriptionKey: "no frame"])
    }
    return pb
}

let pb = try await decode(args[1], at: Double(args[2])!)
let trc = CVBufferCopyAttachment(pb, kCVImageBufferTransferFunctionKey, nil) as? String ?? "-"
let img = CIImage(cvPixelBuffer: pb)
let w = Int(img.extent.width), h = Int(img.extent.height)
var px = [Float](repeating: 0, count: w * h * 4)
CIContext(options: [.workingColorSpace: linear, .workingFormat: CIFormat.RGBAf])
    .render(img, toBitmap: &px, rowBytes: w * 16, bounds: img.extent, format: .RGBAf, colorSpace: linear)

func lum(_ i: Int) -> Float { 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2] }

// paper patch in the left margin, present in every shot
var paper: Float = 0
for y in 250..<350 { for x in 20..<120 { paper += lum((y * w + x) * 4) } }
paper /= 10000

var ls = [Float]()
for y in stride(from: 0, to: h, by: 2) { for x in stride(from: 0, to: w, by: 2) { ls.append(lum((y * w + x) * 4)) } }
ls.sort()
func pct(_ p: Double) -> Float { ls[min(ls.count - 1, Int(Double(ls.count) * p))] }
let over = { (t: Float) in String(format: "%.1f%%", 100 * Double(ls.filter { $0 > t }.count) / Double(ls.count)) }
print(String(format: "%@ @%@s  trc=%@\n  paper %.2f | p50 %.2f p90 %.2f p99 %.2f max %.2f | >1.0 %@  >1.5 %@",
             (args[1] as NSString).lastPathComponent, args[2], trc, paper, pct(0.5), pct(0.9), pct(0.99), ls.last!, over(1.0), over(1.5)))

if args.count > 4 {
    let headroom = Float(args[4])!, border = 60
    let ow = w + 2 * border, oh = h + 2 * border
    func enc(_ v: Float) -> UInt8 {
        let c = min(max(v / headroom, 0), 1)
        let s = c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
        return UInt8(s * 255 + 0.5)
    }
    let ui = enc(1.0)
    var rgb = [UInt8](repeating: ui, count: ow * oh * 3)
    for y in 0..<h { for x in 0..<w {
        let s = (y * w + x) * 4, d = ((y + border) * ow + x + border) * 3
        rgb[d] = enc(px[s]); rgb[d + 1] = enc(px[s + 1]); rgb[d + 2] = enc(px[s + 2])
    } }
    let provider = CGDataProvider(data: Data(rgb) as CFData)!
    let cg = CGImage(width: ow, height: oh, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: ow * 3,
                     space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: 0),
                     provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[3]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cg, nil)
    CGImageDestinationFinalize(dest)
}
