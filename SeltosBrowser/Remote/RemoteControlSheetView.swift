import SwiftUI
import CoreImage.CIFilterBuiltins

/// In-car sheet displaying the 4-digit PIN, dynamic QR Code, seek interval options, and connection status
public struct RemoteControlSheetView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var localServer = LocalRemoteServer.shared
    @ObservedObject private var cloudRelay = CloudRemoteRelay.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with Anjaneya Logo
                    VStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)

                        Text("Wireless Car Remote")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Control browser from any Android or mobile phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)

                    // 1. PIN Code Card (For 4G/5G Cellular Data Mode)
                    VStack(spacing: 8) {
                        Text("4-DIGIT REMOTE PIN")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .tracking(1.2)

                        Text(settings.remotePIN)
                            .font(.system(size: 42, weight: .black, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .tracking(8)

                        Text("Enter this PIN on your Android phone to connect without Hotspot")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)

                    // 2. Seek Interval Selector (5s Default, 10s, 15s, 1m)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "goforward")
                                .foregroundColor(.accentColor)
                            Text("Media Seek Jump Interval")
                                .font(.headline)
                        }

                        Picker("Seek Step", selection: $settings.seekInterval) {
                            ForEach(SeekInterval.allCases) { interval in
                                Text(interval.title).tag(interval)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Applies to steering wheel buttons, lock screen, and wireless remote.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)

                    // 3. QR Code Card (For Instant Scanning)
                    VStack(spacing: 12) {
                        Text("SCAN WITH ANDROID CAMERA")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .tracking(1)

                        if let qrImage = generateQRCode(from: localServer.remoteURL) {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 170, height: 170)
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }

                        Text("Hotspot Address: \(localServer.remoteURL)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)

                        Text("Connect Android to iPhone Hotspot and scan or type URL.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)

                    // 4. Dual-Mode Status Indicator
                    VStack(spacing: 10) {
                        HStack {
                            Circle()
                                .fill(localServer.isRunning ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text("Local Hotspot Server:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(localServer.isRunning ? "Ready (Port \(localServer.serverPort))" : "Starting...")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Circle()
                                .fill(cloudRelay.isConnected ? Color.green : Color.blue)
                                .frame(width: 8, height: 8)
                            Text("4G/5G Cellular Cloud Relay:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(cloudRelay.isConnected ? "Connected (PIN: \(settings.remotePIN))" : "Active (PIN: \(settings.remotePIN))")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(14)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }
            .navigationTitle("Remote Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            RemoteControlManager.shared.startAll()
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter?.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
