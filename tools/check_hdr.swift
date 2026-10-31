// Ask AVFoundation whether each video is treated as HDR, and print its color tags.
// usage: swift check_hdr.swift <video>...
import AVFoundation
import CoreMedia

func describe(_ path: String) async {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    do {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            print("\(path): no video track"); return
        }
        let chars = try await track.load(.mediaCharacteristics)
        let fds = try await track.load(.formatDescriptions)
        let hdr = chars.contains(.containsHDRVideo)
        print("== \((path as NSString).lastPathComponent)")
        print("   containsHDRVideo: \(hdr)")
        for fd in fds {
            let sub = CMFormatDescriptionGetMediaSubType(fd)
            let fourcc = String(bytes: [24, 16, 8, 0].map { UInt8((sub >> $0) & 0xff) }, encoding: .ascii) ?? "?"
            let ext = CMFormatDescriptionGetExtensions(fd) as? [String: Any] ?? [:]
            print("   codec: \(fourcc)")
            for key in ["CVImageBufferColorPrimaries", "CVImageBufferTransferFunction",
                        "CVImageBufferYCbCrMatrix", "BitsPerComponent", "FullRangeVideo"] {
                print("   \(key): \(ext[key] ?? "-")")
            }
        }
    } catch {
        print("\(path): \(error)")
    }
}

for path in CommandLine.arguments.dropFirst() {
    await describe(path)
}
