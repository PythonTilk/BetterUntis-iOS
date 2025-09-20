import SwiftUI
import AVFoundation
import AudioToolbox

struct QRCodeScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingScanner = false
    @State private var hasPermission = false

    let onQRCodeFound: (String) -> Void

    var body: some View {
        NavigationView {
            VStack {
                if hasPermission {
                    QRCodeScannerRepresentable(onQRCodeFound: onQRCodeFound)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("Camera Permission Required")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("To scan QR codes, please allow camera access in Settings")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    hasPermission = granted
                }
            }
        case .denied, .restricted:
            hasPermission = false
        @unknown default:
            hasPermission = false
        }
    }
}

struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    let onQRCodeFound: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        return QRCodeScannerViewController(onQRCodeFound: onQRCodeFound)
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {
        // No updates needed
    }
}

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let onQRCodeFound: (String) -> Void

    init(onQRCodeFound: @escaping (String) -> Void) {
        self.onQRCodeFound = onQRCodeFound
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black

        setupCaptureSession()
    }

    private func setupCaptureSession() {
        // Add safety check for simulator
        #if targetEnvironment(simulator)
        print("⚠️ QR Scanner: Running on simulator, camera not available")
        failed()
        return
        #endif

        captureSession = AVCaptureSession()

        // Check camera permission first
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard cameraAuthStatus == .authorized else {
            print("❌ QR Scanner: Camera not authorized, status: \(cameraAuthStatus)")
            failed()
            return
        }

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ QR Scanner: No video capture device available")
            failed()
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("❌ QR Scanner: Failed to create video input: \(error)")
            failed()
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            print("❌ QR Scanner: Cannot add video input to session")
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("❌ QR Scanner: Cannot add metadata output to session")
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Add scanning overlay
        addScanningOverlay()

        // Start capture session on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }

            print("✅ QR Scanner: Found QR code: \(stringValue)")

            // Safe vibration that works on device but not simulator
            #if !targetEnvironment(simulator)
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            #endif

            onQRCodeFound(stringValue)
        }
    }

    private func addScanningOverlay() {
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        // Create a hole in the overlay
        let path = UIBezierPath(rect: overlayView.bounds)
        let scanAreaSize: CGFloat = 200
        let scanAreaX = (overlayView.bounds.width - scanAreaSize) / 2
        let scanAreaY = (overlayView.bounds.height - scanAreaSize) / 2
        let scanAreaRect = CGRect(x: scanAreaX, y: scanAreaY, width: scanAreaSize, height: scanAreaSize)
        let scanAreaPath = UIBezierPath(rect: scanAreaRect)

        path.append(scanAreaPath.reversing())

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillRule = .evenOdd

        overlayView.layer.mask = shapeLayer
        view.addSubview(overlayView)

        // Add scanning frame
        let frameView = UIView(frame: scanAreaRect)
        frameView.layer.borderColor = UIColor.white.cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 8
        frameView.backgroundColor = UIColor.clear
        view.addSubview(frameView)

        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Position QR code within the frame"
        instructionLabel.textColor = UIColor.white
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLabel.frame = CGRect(x: 20, y: scanAreaY + scanAreaSize + 20, width: view.bounds.width - 40, height: 20)
        view.addSubview(instructionLabel)
    }
}