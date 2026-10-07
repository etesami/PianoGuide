import CoreAudioKit
import SwiftUI

/// Apple's built-in screen for finding and connecting Bluetooth LE MIDI devices.
struct BluetoothMIDIPairingView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: CABTMIDICentralViewController())
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}
