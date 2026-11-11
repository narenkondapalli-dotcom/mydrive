import AVFoundation
import Foundation

/// Records the loved-one line on the PHONE (never in the car UI).
/// Microphone permission is requested only when the driver taps Record. Max 15 s, stored locally in the App Group container.
final class LovedOneRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum State: Equatable { case idle, recording, denied, failed }

    static let recorderSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 22050,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
    ]

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var previewPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var onFinished: ((String) -> Void)?
    private var currentFile = ""

    /// Asks for the microphone (first time only), then records up to `LovedOne.maxSeconds`.
    func start(fileName: String, onFinished: @escaping (String) -> Void) {
        guard state != .recording else { return }
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted { self.begin(fileName: fileName, onFinished: onFinished) } else { self.state = .denied }
            }
        }
    }

    func stop() { recorder?.stop() }

    func preview(url: URL) {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback)
        try? s.setActive(true)
        previewPlayer = try? AVAudioPlayer(contentsOf: url)
        previewPlayer?.play()
    }

    private func begin(fileName: String, onFinished: @escaping (String) -> Void) {
        let url = SharedStore.containerURL.appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try s.setActive(true)
            let r = try AVAudioRecorder(url: url, settings: Self.recorderSettings)
            r.delegate = self
            guard r.record(forDuration: LovedOne.maxSeconds) else { state = .failed; return }
            recorder = r
            currentFile = fileName
            self.onFinished = onFinished
            elapsed = 0
            state = .recording
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { self?.tick() }
            }
        } catch {
            Metrics.shared.log(.error, ["where": "loved_one_record", "msg": error.localizedDescription])
            state = .failed
        }
    }

    private func tick() { elapsed = recorder?.currentTime ?? elapsed }

    private func finished(success: Bool) {
        timer?.invalidate(); timer = nil
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        state = success ? .idle : .failed
        if success { onFinished?(currentFile) }
        onFinished = nil
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async { self.finished(success: flag) }
    }
}
