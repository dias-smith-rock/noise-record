import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let currentZoom: () -> CGFloat
    let onZoomChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(currentZoom: currentZoom, onZoomChange: onZoomChange)
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.isUserInteractionEnabled = true

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        context.coordinator.currentZoom = currentZoom
        context.coordinator.onZoomChange = onZoomChange
    }

    final class Coordinator: NSObject {
        var currentZoom: () -> CGFloat
        var onZoomChange: (CGFloat) -> Void
        private var pinchStartZoom: CGFloat = 1.0

        init(currentZoom: @escaping () -> CGFloat, onZoomChange: @escaping (CGFloat) -> Void) {
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

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
