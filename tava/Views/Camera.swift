import SwiftUI
import UIKit
import PhotosUI

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
            parent.onImageCaptured(imageData)
            parent.dismiss()
        }
        
        func didSelectMultipleImages(_ images: [UIImage]) {
            parent.onMultipleImagesCaptured(images)
            parent.dismiss()
        }
        
        func didCancel() {
            parent.dismiss()
        }
    }
}

class CameraViewController: UIViewController {
    var coordinator: CameraView.Coordinator?
    private var imagePicker: UIImagePickerController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        imagePicker = UIImagePickerController()
        imagePicker?.delegate = self
        imagePicker?.sourceType = .camera
        imagePicker?.allowsEditing = false
        imagePicker?.showsCameraControls = false // Hide default controls
        
        guard let imagePicker = imagePicker else { return }
        
        addChild(imagePicker)
        view.addSubview(imagePicker.view)
        imagePicker.view.frame = view.bounds
        imagePicker.didMove(toParent: self)
        
        // Add our custom controls
        setupCustomControls()
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
        
        // Cancel button (top right to avoid flash conflict)
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
        
        // Flash button (top center)
        let flashButton = UIButton(type: .system)
        flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        flashButton.layer.cornerRadius = 20
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flashButton)
        
        NSLayoutConstraint.activate([
            // Library button - bottom left
            libraryButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            libraryButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            libraryButton.widthAnchor.constraint(equalToConstant: 50),
            libraryButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Cancel button - top right
            cancelButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // Capture button - bottom center
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Flash button - top center
            flashButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    @objc private func capturePhoto() {
        imagePicker?.takePicture()
    }

    @objc private func toggleFlash() {
        // Toggle flash mode
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .off {
                device.torchMode = .on
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Flash toggle failed")
        }
    }

    @objc private func cancelCamera() {
        coordinator?.didCancel()
    }
    
    @objc private func openLibrary() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // Allow unlimited selection
        config.filter = .images
        
        let photoPicker = PHPickerViewController(configuration: config)
        photoPicker.delegate = self
        
        present(photoPicker, animated: true)
    }
}

extension CameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let editedImage = info[.editedImage] as? UIImage,
           let imageData = editedImage.jpegData(compressionQuality: 0.8) {
            coordinator?.didCaptureImage(imageData)
        } else if let originalImage = info[.originalImage] as? UIImage,
                  let imageData = originalImage.jpegData(compressionQuality: 0.8) {
            coordinator?.didCaptureImage(imageData)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        coordinator?.didCancel()
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
