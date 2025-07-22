import SwiftUI
import UIKit
import PhotosUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (Data) -> Void
    let onMultipleImagesCaptured: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.coordinator = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func didCaptureImage(_ imageData: Data) {
            print("didCaptureImage")
            parent.onImageCaptured(imageData)
            
        }
        
        func didSelectMultipleImages(_ images: [UIImage]) {
            parent.onMultipleImagesCaptured(images)
            
        }
        
        func didCancel() {
            parent.dismiss()
        }
    }
}

class CameraViewController: UIViewController {
    var coordinator: CameraView.Coordinator?
    
    private var captureSession: AVCaptureSession!
    private var stillImageOutput: AVCapturePhotoOutput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var currentDevice: AVCaptureDevice!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupCustomControls()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Unable to access back camera!")
            return
        }
        
        currentDevice = backCamera
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        } catch {
            print("Error Unable to initialize back camera: \(error.localizedDescription)")
        }
    }
    
    private func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        videoPreviewLayer.frame = view.bounds
        
        view.layer.addSublayer(videoPreviewLayer)
    }

    private func setupCustomControls() {
        // Library button (bottom left with cards icon)
        let libraryButton = UIButton(type: .system)
        libraryButton.setImage(UIImage(systemName: "rectangle.on.rectangle"), for: .normal)
        libraryButton.tintColor = .white
        libraryButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        libraryButton.layer.cornerRadius = 25
        libraryButton.addTarget(self, action: #selector(openLibrary), for: .touchUpInside)
        
        libraryButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(libraryButton)
        
        // Cancel button (top left)
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelCamera), for: .touchUpInside)
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        // Camera capture button (bottom center)
        let captureButton = UIButton(type: .system)
        captureButton.setImage(UIImage(systemName: "circle"), for: .normal)
        captureButton.tintColor = .white
        captureButton.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 3
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureButton)
        
        // Flash button (top right)
        let flashButton = UIButton(type: .system)
        flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        flashButton.layer.cornerRadius = 20
        flashButton.tag = 100
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flashButton)
        
        NSLayoutConstraint.activate([
            // Library button - bottom left
            libraryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            libraryButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            libraryButton.widthAnchor.constraint(equalToConstant: 50),
            libraryButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Cancel button - top left
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            
            // Capture button - bottom center
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Flash button - top right
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flashButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func toggleFlash() {
        guard let flashButton = view.viewWithTag(100) as? UIButton,
              let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.hasTorch {
                if device.torchMode == .off {
                    device.torchMode = .on
                    flashButton.setImage(UIImage(systemName: "bolt"), for: .normal)
                } else {
                    device.torchMode = .off
                    flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    }

    @objc private func cancelCamera() {
        coordinator?.didCancel()
    }
    
    @objc private func openLibrary() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        
        let photoPicker = PHPickerViewController(configuration: config)
        photoPicker.delegate = self
        
        present(photoPicker, animated: true)
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        coordinator?.didCaptureImage(imageData)
    }
}

extension CameraViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        if results.isEmpty {
            return
        }
        
        let group = DispatchGroup()
        var images: [UIImage] = []
        
        for result in results {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                defer { group.leave() }
                if let image = object as? UIImage {
                    images.append(image)
                }
            }
        }
        
        group.notify(queue: .main) {
            self.coordinator?.didSelectMultipleImages(images)
        }
    }
}
