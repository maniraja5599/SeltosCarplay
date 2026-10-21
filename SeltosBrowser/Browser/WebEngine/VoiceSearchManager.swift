import Foundation
import Speech
import AVFoundation

/// Coordinates native speech recognition and microphone input for voice search
public final class VoiceSearchManager: ObservableObject {
    public static let shared = VoiceSearchManager()

    @Published public var isListening: Bool = false
    @Published public var transcribedText: String = ""
    @Published public var statusMessage: String? = nil

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    public init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    public func toggleListening(onRecognized: @escaping (String) -> Void) {
        if isListening {
            stopListening()
        } else {
            startListening(onRecognized: onRecognized)
        }
    }

    public func startListening(onRecognized: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            if granted {
                                self.beginRecording(onRecognized: onRecognized)
                            } else {
                                self.statusMessage = "Microphone access denied"
                            }
                        }
                    }
                case .denied, .restricted, .notDetermined:
                    self.statusMessage = "Speech recognition permission not granted"
                @unknown default:
                    self.statusMessage = "Speech recognition unavailable"
                }
            }
        }
    }

    private func beginRecording(onRecognized: @escaping (String) -> Void) {
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Audio configuration failed"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            transcribedText = ""
            statusMessage = "Listening... Speak now"
        } catch {
            statusMessage = "Audio engine could not start"
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    let text = result.bestTranscription.formattedString
                    self.transcribedText = text
                    self.statusMessage = text
                    onRecognized(text)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self.stopListening()
                }
            }
        }
    }

    public func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        statusMessage = nil

        // Restore audio session category for CarPlay & YouTube playback
        AudioSessionManager.shared.configureAudioSession()
    }
}
