#if canImport(Speech)
import AVFoundation
import Foundation
import Speech

@MainActor
@Observable
final class VoiceDictator {
    enum State: Equatable {
        case idle
        case authorizing
        case recording
        case denied(String)
        case error(String)
    }

    private(set) var state: State = .idle
    var liveTranscript: String = ""

    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private let audio = AVAudioEngine()

    func start() async {
        liveTranscript = ""
        state = .authorizing
        let speechOK = await requestSpeech()
        guard speechOK else { return }
        let micOK = await requestMic()
        guard micOK else { return }
        do { try beginRecording() }
        catch { state = .error(String(describing: error)) }
    }

    func stop() {
        audio.stop()
        audio.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        if case .recording = state { state = .idle }
    }

    private func requestSpeech() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    if status == .authorized { cont.resume(returning: true) }
                    else { self.state = .denied("Speech recognition not authorized."); cont.resume(returning: false) }
                }
            }
        }
    }

    private func requestMic() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { ok in
                Task { @MainActor in
                    if ok { cont.resume(returning: true) }
                    else { self.state = .denied("Microphone access denied."); cont.resume(returning: false) }
                }
            }
        }
    }

    private func beginRecording() throws {
        recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            state = .error("Speech recognizer unavailable.")
            return
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        audio.prepare()
        try audio.start()

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.liveTranscript = result.bestTranscription.formattedString
                }
                if let error {
                    self?.state = .error(error.localizedDescription)
                    self?.stop()
                }
            }
        }
        state = .recording
    }
}
#else
@MainActor
@Observable
final class VoiceDictator {
    enum State: Equatable { case idle, authorizing, recording, denied(String), error(String) }
    private(set) var state: State = .idle
    var liveTranscript: String = ""
    func start() async { state = .error("Speech unavailable on this platform.") }
    func stop() {}
}
#endif
