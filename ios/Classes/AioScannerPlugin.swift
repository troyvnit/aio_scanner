import Flutter
import UIKit
import VisionKit
import Vision

/**
 * AioScannerPlugin
 *
 * A Flutter plugin that provides document scanning capabilities for iOS using the VisionKit framework.
 * This plugin enables Flutter applications to scan documents and business cards using the native iOS
 * document scanner interface, extract text from scanned images, and save them to a specified directory.
 *
 * Key features:
 * - Document scanning with edge detection and perspective correction
 * - Business card scanning optimization
 * - Optical Character Recognition (OCR) for text extraction
 * - Image saving with configurable output location
 * 
 * The implementation leverages Apple's VisionKit framework for the scanning UI and the Vision
 * framework for text recognition, providing a seamless native experience within Flutter apps.
 */
@objc public class AioScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
    /// The Flutter result callback to return scanning results
    /// This is retained until the scanning process completes or fails
    private var documentScanResult: FlutterResult?
    
    /// Directory path where scanned images will be saved
    /// This is provided by the Flutter application when initiating a scan
    private var outputDirectory: String?
    
    /// Arguments passed from Flutter for the current scan operation
    /// May include parameters like maxNumPages and UI messages
    private var scanArgs: [String: Any]?
    
    /**
     * Registers this plugin with the Flutter engine.
     *
     * This static method sets up the method channel and registers the plugin instance
     * as a method call delegate. This is called automatically by the Flutter framework.
     *
     * - Parameter registrar: The Flutter plugin registrar used to set up the channel.
     *
     * Example of how this is used in the Flutter framework:
     * ```swift
     * GeneratedPluginRegistrant.register(with: self)
     * ```
     */
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "aio_scanner", binaryMessenger: registrar.messenger())
        let instance = AioScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    /**
     * Handles method calls from Flutter.
     *
     * This is the main entry point for communication from Flutter to the native iOS code.
     * It routes incoming method calls to the appropriate implementation based on the method name.
     *
     * Supported methods:
     * - getPlatformVersion: Returns the iOS version.
     * - isDocumentScanningSupported: Checks if document scanning is supported on this device.
     * - startDocumentScanning: Initiates document scanning.
     * - startBusinessCardScanning: Initiates optimized scanning for business cards.
     *
     * All methods return results asynchronously via the result callback.
     *
     * - Parameters:
     *   - call: The method call received from Flutter, containing method name and arguments.
     *   - result: A callback to send results back to Flutter.
     */
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "isDocumentScanningSupported":
            result(VNDocumentCameraViewController.isSupported)
            
        case "startDocumentScanning":
            guard VNDocumentCameraViewController.isSupported else {
                result(["isSuccessful": false, "errorMessage": "Document scanning is not supported on this device"])
                return
            }
            
            guard let args = call.arguments as? [String: Any],
                  let outputDir = args["outputDirectory"] as? String else {
                result(["isSuccessful": false, "errorMessage": "Invalid arguments"])
                return
            }
            
            self.documentScanResult = result
            self.outputDirectory = outputDir
            self.scanArgs = args
            
            DispatchQueue.main.async {
                self.startDocumentScanner()
            }
            
        case "startBusinessCardScanning":
            // Business card scanning uses the same document scanner but with different parameters
            guard VNDocumentCameraViewController.isSupported else {
                result(["isSuccessful": false, "errorMessage": "Document scanning is not supported on this device"])
                return
            }
            
            guard let args = call.arguments as? [String: Any],
                  let outputDir = args["outputDirectory"] as? String else {
                result(["isSuccessful": false, "errorMessage": "Invalid arguments"])
                return
            }
            
            self.documentScanResult = result
            self.outputDirectory = outputDir
            self.scanArgs = args
            
            DispatchQueue.main.async {
                self.startDocumentScanner()
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /**
     * Initiates the document scanner interface.
     *
     * This method creates and presents the native iOS document scanner (VNDocumentCameraViewController),
     * which provides:
     * - Real-time edge detection
     * - Automatic perspective correction
     * - Image enhancement
     * - Multi-page document capture
     *
     * The scanner UI is presented modally over the current view controller.
     * Results are handled by the delegate methods when scanning completes.
     */
    private func startDocumentScanner() {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = self
        
        // Get the root view controller
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            self.documentScanResult?(["isSuccessful": false, "errorMessage": "Unable to find the root view controller"])
            self.documentScanResult = nil
            return
        }
        
        // Present the scanner
        rootViewController.present(scannerViewController, animated: true, completion: nil)
    }
    
    // MARK: - VNDocumentCameraViewControllerDelegate
    
    /**
     * Called when the user successfully completes document scanning.
     *
     * This delegate method is invoked by the VNDocumentCameraViewController when the
     * user finishes scanning one or more document pages. It processes the scanned
     * document by:
     * 1. Saving each scanned image to the specified output directory
     * 2. Performing text recognition on each image sequentially
     * 3. Returning the paths to the saved images and any extracted text
     *
     * The final result is delivered back to Flutter via the saved result callback.
     *
     * - Parameters:
     *   - controller: The document camera view controller.
     *   - scan: The resulting document scan containing the captured images.
     */
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        // Dismiss the scanner
        controller.dismiss(animated: true) {
            // Create the output directory if needed
            let fileManager = FileManager.default
            guard let outputDir = self.outputDirectory else { return }
            
            if !fileManager.fileExists(atPath: outputDir) {
                do {
                    try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    self.documentScanResult?(["isSuccessful": false, "errorMessage": "Failed to create output directory: \(error.localizedDescription)"])
                    self.documentScanResult = nil
                    return
                }
            }
            
            // Save the scanned images
            var imagePaths: [String] = []
            var allText = ""
            
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                let imagePath = "\(outputDir)/scan_\(Date().timeIntervalSince1970)_\(i).jpg"
                
                // Save the image
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    do {
                        try imageData.write(to: URL(fileURLWithPath: imagePath))
                        imagePaths.append(imagePath)
                        
                        // Try to recognize text in the image
                        self.recognizeText(in: image) { text in
                            if let text = text, !text.isEmpty {
                                if !allText.isEmpty {
                                    allText += "\n\n"
                                }
                                allText += text
                            }
                            
                            // If this is the last image, return the result
                            if i == scan.pageCount - 1 {
                                DispatchQueue.main.async {
                                    self.documentScanResult?(["isSuccessful": true, "imagePaths": imagePaths, "extractedText": allText])
                                    self.documentScanResult = nil
                                }
                            }
                        }
                    } catch {
                        self.documentScanResult?(["isSuccessful": false, "errorMessage": "Failed to save image: \(error.localizedDescription)"])
                        self.documentScanResult = nil
                        return
                    }
                }
            }
        }
    }
    
    /**
     * Called when an error occurs during document scanning.
     *
     * This delegate method is invoked when the document scanner encounters an error,
     * such as insufficient system resources or camera access issues. The error is
     * forwarded back to the Flutter application with relevant details.
     *
     * - Parameters:
     *   - controller: The document camera view controller.
     *   - error: The error that occurred during scanning.
     */
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            self.documentScanResult?(["isSuccessful": false, "errorMessage": error.localizedDescription])
            self.documentScanResult = nil
        }
    }
    
    /**
     * Called when the user cancels document scanning.
     *
     * This delegate method is invoked when the user explicitly cancels the scanning
     * process by tapping the cancel button. The cancellation is reported back to
     * the Flutter application.
     *
     * - Parameter controller: The document camera view controller.
     */
    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            self.documentScanResult?(["isSuccessful": false, "errorMessage": "User cancelled scanning"])
            self.documentScanResult = nil
        }
    }
    
    // MARK: - Text Recognition
    
    /**
     * Performs text recognition on the provided image.
     *
     * This method utilizes Apple's Vision framework to extract text from scanned document
     * images. It creates a VNRecognizeTextRequest configured for accurate recognition,
     * which provides high-quality OCR results at the cost of potentially slower processing.
     *
     * The recognized text is returned through the completion handler as a single string
     * with line breaks between text blocks.
     *
     * - Parameters:
     *   - image: The UIImage to extract text from.
     *   - completion: A callback to handle the extracted text (or nil if extraction failed).
     *
     * Example usage:
     * ```swift
     * recognizeText(in: documentImage) { extractedText in
     *     if let text = extractedText {
     *         print("Recognized text: \(text)")
     *     } else {
     *         print("No text recognized or extraction failed")
     *     }
     * }
     * ```
     */
    private func recognizeText(in image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("Text recognition error: \(error)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(recognizedText)
        }
        
        // Configure the text recognition request for high quality results
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform text recognition: \(error)")
            completion(nil)
        }
    }
} 