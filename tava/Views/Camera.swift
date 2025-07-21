//
//  Camera.swift
//  tava
//
//  Created by dilan on 7/20/25.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage,
               let imageData = editedImage.jpegData(compressionQuality: 0.8) {
                parent.onImageCaptured(imageData)
            } else if let originalImage = info[.originalImage] as? UIImage,
                      let imageData = originalImage.jpegData(compressionQuality: 0.8) {
                parent.onImageCaptured(imageData)
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
