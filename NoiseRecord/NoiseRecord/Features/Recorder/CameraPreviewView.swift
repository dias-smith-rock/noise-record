import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var isDualCamera: Bool = false
    var backPreviewPort: AVCaptureInput.Port?
    var frontPreviewPort: AVCaptureInput.Port?
    var isPreviewActive: Bool = true
    var detachGeneration: Int = 0
    let isFrontCamera: () -> Bool
    var zoomGesturesEnabled: Bool = true
    let currentZoom: () -> CGFloat
    let onZoomChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isFrontCamera: isFrontCamera,
            currentZoom: currentZoom,
            onZoomChange: onZoomChange
        )
    }

    func makeUIView(context: Context) -> DualPreviewUIView {
        VideoTabPerformance.mark(.previewViewCreated)
        let view = DualPreviewUIView()
        view.isUserInteractionEnabled = zoomGesturesEnabled
        attachGestures(to: view, coordinator: context.coordinator, enabled: zoomGesturesEnabled)
        return view
    }

    func updateUIView(_ uiView: DualPreviewUIView, context: Context) {
        if detachGeneration != uiView.processedDetachGeneration {
            uiView.detachFromSession()
            uiView.processedDetachGeneration = detachGeneration
        }

        guard isPreviewActive else { return }

        uiView.apply(
            session: session,
            isDualCamera: isDualCamera,
            backPort: backPreviewPort,
            frontPort: frontPreviewPort,
            isFrontCamera: isFrontCamera()
        )
        uiView.isUserInteractionEnabled = zoomGesturesEnabled
        context.coordinator.isFrontCamera = isFrontCamera
        context.coordinator.currentZoom = currentZoom
        context.coordinator.onZoomChange = onZoomChange
    }

    private func attachGestures(to view: DualPreviewUIView, coordinator: Coordinator, enabled: Bool) {
        guard enabled else { return }
        let pinch = UIPinchGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)

        let doubleTap = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
    }

    final class Coordinator: NSObject {
        var isFrontCamera: () -> Bool
        var currentZoom: () -> CGFloat
        var onZoomChange: (CGFloat) -> Void
        private var pinchStartZoom: CGFloat = 1.0

        init(
            isFrontCamera: @escaping () -> Bool,
            currentZoom: @escaping () -> CGFloat,
            onZoomChange: @escaping (CGFloat) -> Void
        ) {
            self.isFrontCamera = isFrontCamera
            self.currentZoom = currentZoom
            self.onZoomChange = onZoomChange
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                pinchStartZoom = currentZoom()
            case .changed:
                onZoomChange(pinchStartZoom * gesture.scale)
            default:
                break
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            let zoom = currentZoom()
            onZoomChange(zoom > 1.05 ? 1.0 : 2.0)
        }
    }
}

final class DualPreviewUIView: UIView {
    private let mainPreviewLayer = AVCaptureVideoPreviewLayer()
    private let pipPreviewLayer = AVCaptureVideoPreviewLayer()
    var processedDetachGeneration = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        mainPreviewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(mainPreviewLayer)

        pipPreviewLayer.videoGravity = .resizeAspectFill
        pipPreviewLayer.isHidden = true
        pipPreviewLayer.cornerRadius = 10
        pipPreviewLayer.masksToBounds = true
        pipPreviewLayer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        pipPreviewLayer.borderWidth = 2
        layer.addSublayer(pipPreviewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mainPreviewLayer.frame = bounds

        let margin = bounds.width * 0.04
        let pipWidth = bounds.width * 0.28
        let pipHeight = pipWidth * 4 / 3
        pipPreviewLayer.frame = CGRect(
            x: bounds.width - margin - pipWidth,
            y: margin,
            width: pipWidth,
            height: pipHeight
        )
    }

    func detachFromSession() {
        mainPreviewLayer.session = nil
        pipPreviewLayer.session = nil
    }

    func apply(
        session: AVCaptureSession,
        isDualCamera: Bool,
        backPort: AVCaptureInput.Port?,
        frontPort: AVCaptureInput.Port?,
        isFrontCamera: Bool
    ) {
        if isDualCamera, let backPort, let frontPort {
            applyDualPreview(session: session, backPort: backPort, frontPort: frontPort)
        } else {
            applySinglePreview(session: session, isFrontCamera: isFrontCamera)
        }
    }

    private func applySinglePreview(session: AVCaptureSession, isFrontCamera: Bool) {
        pipPreviewLayer.isHidden = true
        pipPreviewLayer.session = nil

        if mainPreviewLayer.session !== session {
            mainPreviewLayer.session = nil
            mainPreviewLayer.session = session
        }
        if let connection = mainPreviewLayer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isFrontCamera
        }
    }

    private func applyDualPreview(
        session: AVCaptureSession,
        backPort: AVCaptureInput.Port,
        frontPort: AVCaptureInput.Port
    ) {
        pipPreviewLayer.isHidden = false
        bindPreviewLayer(mainPreviewLayer, session: session, port: backPort, mirrored: false)
        bindPreviewLayer(pipPreviewLayer, session: session, port: frontPort, mirrored: true)
    }

    private func bindPreviewLayer(
        _ previewLayer: AVCaptureVideoPreviewLayer,
        session: AVCaptureSession,
        port: AVCaptureInput.Port,
        mirrored: Bool
    ) {
        previewLayer.setSessionWithNoConnection(session)

        if let connection = previewLayer.connection,
           connection.inputPorts.contains(where: { $0 === port }) {
            applyRotationAndMirror(connection, mirrored: mirrored)
            return
        }

        session.beginConfiguration()
        let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewLayer)
        if session.canAddConnection(connection) {
            session.addConnection(connection)
        }
        session.commitConfiguration()
        applyRotationAndMirror(previewLayer.connection, mirrored: mirrored)
    }

    private func applyRotationAndMirror(_ connection: AVCaptureConnection?, mirrored: Bool) {
        guard let connection else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}
