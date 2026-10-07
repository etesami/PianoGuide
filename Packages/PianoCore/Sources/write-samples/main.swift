// Writes the sample songs as .mid files:  swift run write-samples <dir>
// Or the test songs for trying the import:  swift run write-samples --test-songs <dir>
import Foundation
import PianoCore

let args = Array(CommandLine.arguments.dropFirst())
let testSongs = args.first == "--test-songs"
guard args.count == (testSongs ? 2 : 1) else {
    print("usage: write-samples [--test-songs] <dir>")
    exit(1)
}
let dir = URL(fileURLWithPath: args.last!)
let files: [(name: String, data: Data)] = testSongs
    ? TestSongs.all.map { ($0.name, MIDIFileWriter.write($0.song, singleTrack: $0.singleTrack)) }
    : SampleSongs.all.map { ($0.name, MIDIFileWriter.write($0.song)) }
for file in files {
    let url = dir.appendingPathComponent(file.name + ".mid")
    try file.data.write(to: url)
    print("wrote \(url.path)")
}
