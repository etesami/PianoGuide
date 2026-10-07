// Writes the sample songs as .mid files:  swift run write-samples <dir>
import Foundation
import PianoCore

let args = CommandLine.arguments
guard args.count == 2 else {
    print("usage: write-samples <dir>")
    exit(1)
}
let url = URL(fileURLWithPath: args[1]).appendingPathComponent("twinkle.mid")
try MIDIFileWriter.write(SampleSongs.twinkle).write(to: url)
print("wrote \(url.path)")
