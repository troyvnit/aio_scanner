import Flutter
import UIKit
import VisionKit
import Vision
import PDFKit

/**
 * AioScannerPlugin
 *
 * A Flutter plugin that provides document and barcode scanning capabilities for iOS using the VisionKit framework.
 * This plugin enables Flutter applications to scan documents and barcodes using the native iOS
 * scanner interfaces, extract text from scanned images, and save them to a specified directory.
 *
 * Key features:
 * - Document scanning with edge detection and perspective correction
 * - Barcode scanning for QR codes, UPC, EAN, and other formats
 * - Optical Character Recognition (OCR) for text extraction
 * - Image saving with configurable output location
 * - PDF generation from scanned documents
 * 
 * The implementation leverages Apple's VisionKit framework for the scanning UI and the Vision
 * framework for text recognition, providing a seamless native experience within Flutter apps.
 */
@objc public class AioScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate, DataScannerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    /// The Flutter result callback to return scanning results
    /// This is retained until the scanning process completes or fails
    private var documentScanResult: FlutterResult?
    private var barcodeScanResult: FlutterResult?
    
    /// Directory path where scanned images will be saved
    /// This is provided by the Flutter application when initiating a scan
    private var outputDirectory: String?
    
    /// Arguments passed from Flutter for the current scan operation
    /// May include parameters like maxNumPages and UI messages
    private var scanArgs: [String: Any]?
    
    /// Detected barcodes during barcode scanning
    @available(iOS 16.0, *)
    private var detectedBarcodes: [RecognizedItem.Barcode] = []
    
    /// Data scanner view controller instance for barcode scanning
    @available(iOS 16.0, *)
    private var dataScannerViewController: DataScannerViewController?
    
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
     * - isBarcodeScanningSupported: Checks if barcode scanning is supported on this device.
     * - startDocumentScanning: Initiates document scanning.
     * - startBarcodeScanning: Initiates barcode scanning.
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
            
        case "isBarcodeScanningSupported":
            if #available(iOS 16.0, *) {
                result(DataScannerViewController.isSupported && DataScannerViewController.isAvailable)
            } else {
                result(false)
            }
            
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
            
        case "startBarcodeScanning":
            if #available(iOS 16.0, *) {
                guard DataScannerViewController.isSupported && DataScannerViewController.isAvailable else {
                    result(["isSuccessful": false, "errorMessage": "Barcode scanning is not supported on this device"])
                    return
                }

                guard let args = call.arguments as? [String: Any] else {
                    result(["isSuccessful": false, "errorMessage": "Invalid arguments"])
                    return
                }
                
                self.barcodeScanResult = result
                self.scanArgs = args
                
                // Get barcode formats to recognize
                var recognizedFormats = args["recognizedFormats"] as? [String] ?? []
                
                DispatchQueue.main.async {
                    self.startBarcodeScanner(recognizedFormats: recognizedFormats)
                }
            } else {
                result(["isSuccessful": false, "errorMessage": "Barcode scanning requires iOS 16.0 or later"])
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /**
     * Gets the root view controller of the application.
     *
     * This method attempts to find the key window and its root view controller
     * using an approach that works on iOS 13 and newer.
     *
     * - Returns: The root view controller, or nil if it couldn't be found.
     */
    private func getRootViewController() -> UIViewController? {
        // For iOS 13 and later
        if #available(iOS 13.0, *) {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            return scene?.windows.first?.rootViewController
        } else {
            // Fallback for older iOS versions
            return UIApplication.shared.keyWindow?.rootViewController
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
        guard let rootViewController = getRootViewController() else {
            self.documentScanResult?(["isSuccessful": false, "errorMessage": "Unable to find the root view controller"])
            self.documentScanResult = nil
            return
        }
        
        // Present the scanner
        rootViewController.present(scannerViewController, animated: true, completion: nil)
    }
    
    /**
     * Initiates the barcode scanner interface.
     *
     * This method creates and presents the native iOS barcode scanner (DataScannerViewController),
     * which provides:
     * - Real-time barcode detection
     * - Support for multiple barcode formats
     * - Automatic focus and exposure adjustment
     *
     * The scanner UI is presented modally over the current view controller.
     * Results are handled by the delegate methods when barcodes are recognized.
     *
     * - Parameter recognizedFormats: Array of barcode format strings to recognize
     */
    @available(iOS 16.0, *)
    private func startBarcodeScanner(recognizedFormats: [String]) {
        // Reset detected barcodes
        self.detectedBarcodes = []
        
        // Configure recognized data types
        var dataTypes: Set<DataScannerViewController.RecognizedDataType> = []
        
        if recognizedFormats.isEmpty {
            // If no specific formats are requested, recognize all barcodes
            dataTypes.insert(.barcode())
        } else {
            // Create an array to collect all the barcode symbologies
            var allBarcodeTypes: [DataScannerViewController.RecognizedDataType] = []
            
            // Map format strings to appropriate barcode symbologies
            for format in recognizedFormats {
                switch format.lowercased() {
                case "qr":
                    allBarcodeTypes.append(.barcode(symbologies: [.qr]))
                case "code128":
                    allBarcodeTypes.append(.barcode(symbologies: [.code128]))
                case "code39":
                    allBarcodeTypes.append(.barcode(symbologies: [.code39]))
                case "code93":
                    allBarcodeTypes.append(.barcode(symbologies: [.code93]))
                case "ean8":
                    allBarcodeTypes.append(.barcode(symbologies: [.ean8]))
                case "ean13":
                    allBarcodeTypes.append(.barcode(symbologies: [.ean13]))
                case "upc":
                    allBarcodeTypes.append(.barcode(symbologies: [.upce]))
                    allBarcodeTypes.append(.barcode(symbologies: [.ean13])) // UPC-A is encoded as EAN-13
                case "pdf417":
                    allBarcodeTypes.append(.barcode(symbologies: [.pdf417]))
                case "aztec":
                    allBarcodeTypes.append(.barcode(symbologies: [.aztec]))
                case "datamatrix":
                    allBarcodeTypes.append(.barcode(symbologies: [.dataMatrix]))
                case "itf":
                    allBarcodeTypes.append(.barcode(symbologies: [.itf14]))
                default:
                    // Unknown format, ignore
                    break
                }
            }
            
            // Add all collected types to the set
            for type in allBarcodeTypes {
                dataTypes.insert(type)
            }
            
            if dataTypes.isEmpty {
                // If no valid formats were specified, fall back to all barcode formats
                dataTypes.insert(.barcode())
            }
        }
        
        // Configure scanner
        let dataScannerViewController = DataScannerViewController(
            recognizedDataTypes: dataTypes,
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        
        // Set delegate
        dataScannerViewController.delegate = self
        
        // Configure UI message if available
        if let scanningMessage = self.scanArgs?["scanningMessage"] as? String {
            // Note: The guidanceContentState property is only available in iOS 17+
            // We'll just log the message for now since we're targeting iOS 16.0
            #if DEBUG
            print("Scanning message: \(scanningMessage)")
            #endif
        }
        
        self.dataScannerViewController = dataScannerViewController
        
        // Get the root view controller
        guard let rootViewController = getRootViewController() else {
            self.barcodeScanResult?(["isSuccessful": false, "errorMessage": "Unable to find the root view controller"])
            self.barcodeScanResult = nil
            return
        }
        
        // Present the scanner
        rootViewController.present(dataScannerViewController, animated: true) {
            do {
                // Set the presentation controller delegate to handle interactive dismissal
                dataScannerViewController.presentationController?.delegate = self
                try dataScannerViewController.startScanning()
            } catch {
                self.dismissBarcodeScanner(withResult: ["isSuccessful": false, "errorMessage": "Failed to start scanning: \(error.localizedDescription)"])
            }
        }
    }
    
    /**
     * Dismisses the barcode scanner and returns the result to Flutter.
     *
     * - Parameter result: The result to return to Flutter.
     */
    @available(iOS 16.0, *)
    private func dismissBarcodeScanner(withResult result: [String: Any]) {
        DispatchQueue.main.async {
            self.dataScannerViewController?.dismiss(animated: true) {
                self.barcodeScanResult?(result)
                self.barcodeScanResult = nil
                self.dataScannerViewController = nil
            }
        }
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
     * 3. Generating PDF(s) from the scanned images if requested
     * 4. Returning the paths to the saved images or PDF(s)
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
            
            // Create thumbnail directory
            let thumbnailDir = (outputDir as NSString).appendingPathComponent("thumbnails")
            if !fileManager.fileExists(atPath: thumbnailDir) {
                do {
                    try fileManager.createDirectory(atPath: thumbnailDir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create thumbnail directory: \(error)")
                }
            }
            
            // Save the scanned images
            var imagePaths: [String] = []
            var thumbnailPaths: [String] = []
            var allText = ""
            var images: [UIImage] = []
            
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                let timestamp = Date().timeIntervalSince1970
                let imagePath = "\(outputDir)/scan_\(timestamp)_\(i).jpg"
                let thumbnailPath = "\(thumbnailDir)/scan_\(timestamp)_\(i)_thumb.jpg"
                
                // Generate thumbnail
                let thumbnailSize = CGSize(width: 300, height: 300)
                let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
                let thumbnailImage = renderer.image { context in
                    image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                }
                
                // Save the image and thumbnail
                if let imageData = image.jpegData(compressionQuality: 0.8),
                   let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.8) {
                    do {
                        try imageData.write(to: URL(fileURLWithPath: imagePath))
                        try thumbnailData.write(to: URL(fileURLWithPath: thumbnailPath))
                        imagePaths.append(imagePath)
                        thumbnailPaths.append(thumbnailPath)
                        images.append(image)
                        
                        // Try to recognize text in the image
                        self.recognizeText(in: image) { text in
                            if let text = text, !text.isEmpty {
                                if !allText.isEmpty {
                                    allText += "\n\n"
                                }
                                allText += text
                            }
                            
                            // If this is the last image, generate PDF if requested and return the result
                            if i == scan.pageCount - 1 {
                                // Check if PDF output was requested
                                let outputFormat = self.scanArgs?["outputFormat"] as? String
                                let shouldGeneratePDF = outputFormat == "pdf"
                                let shouldMergePDF = self.scanArgs?["mergePDF"] as? Bool ?? true
                                
                                DispatchQueue.main.async {
                                    var result: [String: Any] = [
                                        "isSuccessful": true,
                                        "extractedText": allText,
                                        "thumbnailPaths": thumbnailPaths
                                    ]
                                    
                                    if shouldGeneratePDF {
                                        if shouldMergePDF {
                                            // Generate single PDF with all pages
                                            if let pdfPath = self.generatePDF(from: images, outputDirectory: outputDir) {
                                                result["filePaths"] = [pdfPath]
                                            } else {
                                                result["filePaths"] = imagePaths
                                            }
                                        } else {
                                            // Generate individual PDFs for each page
                                            let pdfPaths = images.enumerated().compactMap { index, image in
                                                self.generateSinglePagePDF(from: image, outputDirectory: outputDir, pageIndex: index)
                                            }
                                            
                                            if !pdfPaths.isEmpty {
                                                result["filePaths"] = pdfPaths
                                            } else {
                                                result["filePaths"] = imagePaths
                                            }
                                        }
                                    } else {
                                        // Return individual image paths
                                        result["filePaths"] = imagePaths
                                    }
                                    
                                    self.documentScanResult?(result)
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
    
    // MARK: - DataScannerViewControllerDelegate
    
    /**
     * Called when items are added during barcode scanning.
     *
     * This delegate method is invoked when the barcode scanner recognizes new barcodes.
     * It processes the detected barcodes and returns the results to Flutter.
     *
     * - Parameters:
     *   - controller: The data scanner view controller.
     *   - addedItems: The newly recognized items (barcodes).
     *   - allItems: All currently recognized items.
     */
    @available(iOS 16.0, *)
    public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        // Process only barcode items
        let newBarcodes = addedItems.compactMap { item -> RecognizedItem.Barcode? in
            if case .barcode(let barcode) = item {
                return barcode
            }
            return nil
        }
        
        // Add new barcodes to our collection
        self.detectedBarcodes.append(contentsOf: newBarcodes)
        
        // If we have at least one barcode, process it
        if !self.detectedBarcodes.isEmpty {
            processScannedBarcodes()
        }
    }
    
    /**
     * Called when the user taps on the cancel button in the barcode scanner.
     *
     * This delegate method is invoked when the user explicitly cancels the barcode scanning
     * process. The cancellation is reported back to the Flutter application.
     *
     * - Parameter controller: The data scanner view controller.
     */
    @available(iOS 16.0, *)
    public func dataScannerDidCancel(_ dataScanner: DataScannerViewController) {
        dismissBarcodeScanner(withResult: ["isSuccessful": false, "errorMessage": "User cancelled scanning"])
    }
    
    /**
     * Called when an error occurs during barcode scanning.
     *
     * This delegate method is invoked when the barcode scanner encounters an error.
     * The error is forwarded back to the Flutter application with relevant details.
     *
     * - Parameters:
     *   - controller: The data scanner view controller.
     *   - error: The error that occurred during scanning.
     */
    @available(iOS 16.0, *)
    public func dataScanner(_ dataScanner: DataScannerViewController, didFailWithError error: Error) {
        dismissBarcodeScanner(withResult: ["isSuccessful": false, "errorMessage": error.localizedDescription])
    }
    
    /**
     * Processes the scanned barcodes and returns the results to Flutter.
     */
    @available(iOS 16.0, *)
    private func processScannedBarcodes() {
        // Stop scanning to prevent multiple callbacks
        self.dataScannerViewController?.stopScanning()
        
        // Extract barcode values and formats
        var barcodeValues: [String] = []
        var barcodeFormats: [String] = []
        
        for barcode in self.detectedBarcodes {
            if let value = barcode.payloadStringValue {
                barcodeValues.append(value)
                
                // Map the symbology type to a format string
                let format: String
                
                if barcode.observation.symbology == .qr {
                    format = "qr"
                } else if barcode.observation.symbology == .code128 {
                    format = "code128"
                } else if barcode.observation.symbology == .code39 {
                    format = "code39"
                } else if barcode.observation.symbology == .code93 {
                    format = "code93"
                } else if barcode.observation.symbology == .ean8 {
                    format = "ean8"
                } else if barcode.observation.symbology == .ean13 {
                    format = "ean13"
                } else if barcode.observation.symbology == .upce {
                    format = "upce"
                } else if barcode.observation.symbology == .pdf417 {
                    format = "pdf417"
                } else if barcode.observation.symbology == .aztec {
                    format = "aztec"
                } else if barcode.observation.symbology == .dataMatrix {
                    format = "datamatrix"
                } else if barcode.observation.symbology == .itf14 {
                    format = "itf"
                } else {
                    format = "unknown"
                }
                
                barcodeFormats.append(format)
            }
        }
        
        // Prepare result
        var result: [String: Any] = [
            "isSuccessful": !barcodeValues.isEmpty,
            "barcodeValues": barcodeValues,
            "barcodeFormats": barcodeFormats
        ]
        
        if barcodeValues.isEmpty {
            result["errorMessage"] = "No barcodes detected"
        }
        
        // Dismiss the scanner and return the result
        dismissBarcodeScanner(withResult: result)
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
                #if DEBUG
                print("Text recognition error: \(error)")
                #endif
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
            #if DEBUG
            print("Failed to perform text recognition: \(error)")
            #endif
            completion(nil)
        }
    }
    
    /**
     * Generates a PDF document from an array of images.
     *
     * This method creates a PDF document containing all the provided images,
     * with each image on a separate page. The PDF is saved to the specified
     * output directory with a timestamp-based filename.
     *
     * - Parameters:
     *   - images: Array of UIImage objects to include in the PDF.
     *   - outputDirectory: Directory path where the PDF will be saved.
     * - Returns: The path to the generated PDF file, or nil if generation failed.
     */
    private func generatePDF(from images: [UIImage], outputDirectory: String) -> String? {
        let pdfDocument = PDFDocument()
        let timestamp = Date().timeIntervalSince1970
        let pdfPath = "\(outputDirectory)/scan_\(timestamp).pdf"
        
        for (index, image) in images.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        do {
            try pdfDocument.write(to: URL(fileURLWithPath: pdfPath))
            return pdfPath
        } catch {
            print("Failed to generate PDF: \(error.localizedDescription)")
            return nil
        }
    }
    
    /**
     * Generates a single-page PDF from a UIImage.
     *
     * - Parameters:
     *   - image: The UIImage to convert to PDF.
     *   - outputDirectory: Directory where the PDF will be saved.
     *   - pageIndex: Index of the page for the filename.
     * - Returns: The path to the generated PDF file, or nil if generation failed.
     */
    private func generateSinglePagePDF(from image: UIImage, outputDirectory: String, pageIndex: Int) -> String? {
        let pdfPath = "\(outputDirectory)/scan_\(Date().timeIntervalSince1970)_\(pageIndex).pdf"
        let pdfURL = URL(fileURLWithPath: pdfPath)
        
        // Create PDF context
        UIGraphicsBeginPDFContextToFile(pdfPath, CGRect.zero, nil)
        UIGraphicsBeginPDFPage()
        
        // Draw the image
        let imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        image.draw(in: imageRect)
        
        // Close PDF context
        UIGraphicsEndPDFContext()
        
        return pdfPath
    }
    
    /**
     * Generates a thumbnail for a file (image or PDF)
     *
     * - Parameters:
     *   - filePath: Path to the file to generate thumbnail for
     *   - size: Size of the thumbnail (width and height)
     * - Returns: Path to the generated thumbnail image, or nil if generation failed
     */
    private func generateThumbnail(for filePath: String, size: CGSize = CGSize(width: 300, height: 300)) -> String? {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Create thumbnail directory if it doesn't exist
        let thumbnailDir = (fileURL.deletingLastPathComponent().path as NSString).appendingPathComponent("thumbnails")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: thumbnailDir) {
            do {
                try fileManager.createDirectory(atPath: thumbnailDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create thumbnail directory: \(error)")
                return nil
            }
        }
        
        // Generate thumbnail path
        let thumbnailPath = (thumbnailDir as NSString).appendingPathComponent("\(fileURL.deletingPathExtension().lastPathComponent)_thumb.jpg")
        
        // Check if thumbnail already exists
        if fileManager.fileExists(atPath: thumbnailPath) {
            return thumbnailPath
        }
        
        if fileExtension == "pdf" {
            // Generate PDF thumbnail
            guard let pdfDocument = PDFDocument(url: fileURL),
                  let firstPage = pdfDocument.page(at: 0) else {
                return nil
            }
            
            let pageRect = firstPage.bounds(for: .mediaBox)
            let scale = min(size.width / pageRect.width, size.height / pageRect.height)
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
            
            let thumbnailImage = firstPage.thumbnail(of: scaledSize, for: .mediaBox)
            
            // Save thumbnail
            if let imageData = thumbnailImage.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: URL(fileURLWithPath: thumbnailPath))
                    return thumbnailPath
                } catch {
                    print("Failed to save PDF thumbnail: \(error)")
                    return nil
                }
            }
        } else {
            // Generate image thumbnail
            guard let image = UIImage(contentsOfFile: filePath) else {
                return nil
            }
            
            let renderer = UIGraphicsImageRenderer(size: size)
            let thumbnailImage = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            
            // Save thumbnail
            if let imageData = thumbnailImage.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: URL(fileURLWithPath: thumbnailPath))
                    return thumbnailPath
                } catch {
                    print("Failed to save image thumbnail: \(error)")
                    return nil
                }
            }
        }
        
        return nil
    }
    
    // MARK: - UIAdaptivePresentationControllerDelegate
    
    /**
     * Called when the user swipes down to dismiss the presented view controller.
     * 
     * This delegate method is invoked when an interactive dismissal is about to happen,
     * such as when the user swipes down on a modal presentation. We use this to properly
     * handle the dismissal and return a "cancelled" result to Flutter.
     *
     * - Parameter presentationController: The presentation controller being dismissed.
     */
    public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        // Only handle this for barcode scanner
        if #available(iOS 16.0, *),
           presentationController.presentedViewController === self.dataScannerViewController {
            // The user is swiping down to dismiss - handle it the same as a cancellation
            dismissBarcodeScanner(withResult: ["isSuccessful": false, "barcodeValues": [], "barcodeFormats": [], "errorMessage": "User cancelled scanning"])
        }
    }
} 