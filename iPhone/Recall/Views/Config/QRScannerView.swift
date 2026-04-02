import AudioToolbox
import AVFoundation
import SwiftUI
import UIKit

struct QRScannerView: View {
    let onScan: (QRServerConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraPermissionDenied {
                    cameraPermissionDeniedView
                } else {
                    QRCameraPreview(onCodeScanned: handleScannedCode)
                        .ignoresSafeArea()
                }

                VStack {
                    Spacer()
                    Text("Point camera at server config QR code")
                        .font(.caption.monospaced())
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 40)
                }
            }
            .background(.black)
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await checkCameraPermission()
            }
        }
    }

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Access Required")
                .font(.headline)
            Text("Enable camera access in Settings to scan QR codes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                cameraPermissionDenied = true
            }
        case .denied, .restricted:
            cameraPermissionDenied = true
        case .authorized:
            break
        @unknown default:
            break
        }
    }

    private func handleScannedCode(_ code: String) {
        guard let data = code.data(using: .utf8),
              let config = try? JSONDecoder().decode(QRServerConfig.self, from: data) else {
            return
        }
        onScan(config)
        dismiss()
    }
}

// MARK: - Camera Preview

private struct QRCameraPreview: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

// MARK: - Scanner ViewController

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func setupCaptureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        guard captureSession.canAddInput(videoInput) else { return }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else { return }
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue else {
            return
        }

        hasScanned = true
        captureSession.stopRunning()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(stringValue)
    }
}
