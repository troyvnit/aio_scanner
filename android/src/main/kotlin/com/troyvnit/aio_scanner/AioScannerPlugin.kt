package com.troyvnit.aio_scanner

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.common.InputImage
import com.google.android.gms.tasks.Task
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import android.provider.MediaStore
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor

/**
 * # AioScannerPlugin
 * 
 * A comprehensive Flutter plugin that seamlessly integrates Google's ML Kit Document Scanner
 * into Flutter applications. This plugin provides a bridge between Flutter code and native
 * Android functionality to deliver a powerful document scanning experience.
 * 
 * ## Key Features
 * - High-quality document scanning with edge detection
 * - Multi-page document support
 * - Text recognition (OCR) from scanned documents
 * - Barcode scanning with multiple format support
 * - Background processing to maintain UI responsiveness
 * 
 * The implementation uses Google's GMS ML Kit Document Scanner, which provides a native UI
 * for capturing documents, and combines it with ML Kit's text recognition capabilities.
 */
class AioScannerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    /**
     * The MethodChannel that facilitates communication between Flutter and native Android.
     * This channel is used to receive method calls from Flutter and return results.
     */
    private lateinit var channel: MethodChannel
    
    /**
     * Application context used for accessing content providers, system services,
     * and other context-dependent functionality.
     */
    private lateinit var context: Context
    
    /**
     * Reference to the current Activity, required for launching the document scanner
     * and handling activity results.
     */
    private var activity: Activity? = null

    /**
     * Stores the Flutter result callback to be invoked when scanning completes.
     * This allows for asynchronous resolution of the Flutter method call
     * after the document scanning process finishes.
     */
    private var pendingResult: Result? = null
    
    /**
     * Directory path where scanned document images will be saved.
     * This is provided by the Flutter application when initiating a scan.
     */
    private var outputDirectory: String? = null
    
    /**
     * Arguments passed from Flutter for the current scan operation.
     * May include configuration options for the scanner.
     */
    private var currentScanArgs: Map<String, Any>? = null
    
    /**
     * Handler for posting results back to the main thread.
     * Ensures UI-related operations happen on the main thread, as required by Android.
     */
    private val mainHandler = Handler(Looper.getMainLooper())
    
    /**
     * Executor for background processing of images and text recognition.
     * Prevents blocking the main thread during computationally intensive tasks.
     */
    private val executor = Executors.newSingleThreadExecutor()

    /**
     * Lazy-initialized ML Kit document scanner client.
     * This approach defers creation until actually needed, optimizing resource usage.
     * Initialized with default scanning options that will be overridden when starting the scanner.
     */
    private val documentScanner by lazy {
        val options = GmsDocumentScannerOptions.Builder()
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options)
    }
    
    /**
     * Lazy-initialized ML Kit text recognizer for OCR functionality.
     * Uses the default Latin language model for text extraction.
     */
    private val textRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    /**
     * Request code for barcode scanning activity.
     */
    private val BARCODE_SCAN_REQUEST_CODE = 101
    
    /**
     * List of barcode formats to recognize.
     */
    private var barcodeFormats: List<String> = listOf()

    /**
     * Called when the plugin is attached to the Flutter engine.
     * 
     * This is where we initialize the plugin's communication channel and register
     * as the method call handler.
     * 
     * @param flutterPluginBinding The binding to the Flutter engine, providing access to
     *                             Flutter-specific resources and context.
     */
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "aio_scanner")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    /**
     * Handles method calls from Flutter.
     * 
     * This is the main entry point for Flutter to interact with the native Android plugin.
     * The method handles several operations:
     * 
     * - "getPlatformVersion": Returns the Android version.
     * - "isDocumentScanningSupported": Checks if document scanning is supported on the device.
     * - "startDocumentScanning": Initiates the document scanning process.
     * - "isBarcodeScanningSupported": Checks if barcode scanning is supported on the device.
     * - "startBarcodeScanning": Initiates barcode scanning.
     * 
     * @param call The method call from Flutter containing the method name and arguments.
     * @param result The result handler to send responses back to Flutter.
     */
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "isDocumentScanningSupported" -> {
                // ML Kit Document Scanner should be available on most devices with Google Play Services
                result.success(true)
            }
            "startDocumentScanning" -> {
                try {
                    if (activity == null) {
                        result.error("NO_ACTIVITY", "No activity available", null)
                        return
                    }

                    val args = call.arguments as? Map<String, Any>
                    if (args == null) {
                        result.error("INVALID_ARGUMENTS", "Arguments were null", null)
                        return
                    }

                    val outputDir = args["outputDirectory"] as? String
                    if (outputDir == null) {
                        result.error("INVALID_ARGUMENTS", "Output directory was not provided", null)
                        return
                    }

                    // Save the result to resolve later
                    pendingResult = result
                    outputDirectory = outputDir
                    currentScanArgs = args

                    startDocumentScanner()
                } catch (e: Exception) {
                    result.error("ERROR", e.message, e.stackTraceToString())
                }
            }
            "isBarcodeScanningSupported" -> {
                // ML Kit Barcode Scanning should be available on most devices with Google Play Services
                result.success(true)
            }
            "startBarcodeScanning" -> {
                try {
                    if (activity == null) {
                        result.error("NO_ACTIVITY", "No activity available", null)
                        return
                    }

                    val args = call.arguments as? Map<String, Any>
                    if (args == null) {
                        result.error("INVALID_ARGUMENTS", "Arguments were null", null)
                        return
                    }

                    // Save the result to resolve later
                    pendingResult = result
                    currentScanArgs = args
                    
                    // Get barcode formats to recognize
                    barcodeFormats = args["recognizedFormats"] as? List<String> ?: listOf()

                    startBarcodeScanner()
                } catch (e: Exception) {
                    result.error("ERROR", e.message, e.stackTraceToString())
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Starts the document scanner with appropriate configuration.
     * 
     * This method initializes the document scanner with the correct settings,
     * launches the scanner activity, and handles potential errors.
     * 
     * The scanner provides a complete document scanning experience with:
     * - Automatic edge detection
     * - Real-time edge detection
     * - Perspective correction
     * - Multi-page support
     * - Gallery import
     */
    private fun startDocumentScanner() {
        try {
            // Configure scanner options
            val scannerOptions = GmsDocumentScannerOptions.Builder()
                .setGalleryImportAllowed(currentScanArgs?.get("allowGalleryImport") as? Boolean ?: true)
                .setPageLimit(currentScanArgs?.get("maxNumPages") as? Int ?: 5)
                .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
                .build()

            // Create a new scanner client with these specific options
            val scanner = GmsDocumentScanning.getClient(scannerOptions)
            
            // Get and launch the scanner intent
            scanner.getStartScanIntent(activity!!)
                .addOnSuccessListener { intentSender ->
                    // Note: Starting activity with IntentSender instead of Intent
                    activity?.startIntentSenderForResult(
                        intentSender, 
                        DOCUMENT_SCAN_REQUEST_CODE,
                        null, 0, 0, 0
                    )
                }
                .addOnFailureListener { e ->
                    pendingResult?.error("SCANNER_ERROR", "Failed to start scanner: ${e.message}", null)
                    pendingResult = null
                }
        } catch (e: Exception) {
            pendingResult?.error("SCANNER_ERROR", "Failed to start scanner: ${e.message}", null)
            pendingResult = null
        }
    }

    /**
     * Starts the barcode scanner with appropriate configuration.
     * 
     * This method implements a real-time barcode scanning experience using CameraX
     * and ML Kit. It automatically detects barcodes in the camera preview without
     * requiring the user to capture a photo.
     */
    private fun startBarcodeScanner() {
        try {
            if (activity == null) {
                pendingResult?.error("NO_ACTIVITY", "No activity available", null)
                pendingResult = null
                return
            }

            // Create the barcode scanner
            val scannerOptions = createBarcodeScannerOptions()
            val scanner = BarcodeScanning.getClient(scannerOptions)
            
            // Create CameraX intent
            val intent = Intent(activity, BarcodeScannerActivity::class.java)
            
            // Pass barcode formats as an extra
            intent.putStringArrayListExtra("barcodeFormats", ArrayList(barcodeFormats))
            
            // Start the activity
            activity?.startActivityForResult(intent, BARCODE_SCAN_REQUEST_CODE)
        } catch (e: Exception) {
            pendingResult?.error("SCANNER_ERROR", "Failed to start barcode scanner: ${e.message}", null)
            pendingResult = null
        }
    }

    /**
     * Creates barcode scanner options based on the requested formats.
     */
    private fun createBarcodeScannerOptions(): BarcodeScannerOptions {
        return if (barcodeFormats.isEmpty()) {
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
                .build()
        } else {
            // Map format strings to Barcode format constants
            var formatFlags = 0
            for (format in barcodeFormats) {
                val flag = when (format.lowercase()) {
                    "qr" -> Barcode.FORMAT_QR_CODE
                    "code128" -> Barcode.FORMAT_CODE_128
                    "code39" -> Barcode.FORMAT_CODE_39
                    "code93" -> Barcode.FORMAT_CODE_93
                    "ean8" -> Barcode.FORMAT_EAN_8
                    "ean13" -> Barcode.FORMAT_EAN_13
                    "upc" -> Barcode.FORMAT_UPC_A or Barcode.FORMAT_UPC_E
                    "pdf417" -> Barcode.FORMAT_PDF417
                    "aztec" -> Barcode.FORMAT_AZTEC
                    "datamatrix" -> Barcode.FORMAT_DATA_MATRIX
                    "itf" -> Barcode.FORMAT_ITF
                    else -> 0 // Skip unknown formats
                }
                formatFlags = formatFlags or flag
            }
            
            // If no valid formats were specified, use all formats
            if (formatFlags == 0) {
                formatFlags = Barcode.FORMAT_ALL_FORMATS
            }
            
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(formatFlags)
                .build()
        }
    }

    /**
     * Process the activity result from the barcode scanner.
     * 
     * This method is updated to handle results from the BarcodeScannerActivity.
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == DOCUMENT_SCAN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                handleScanResult(data)
                return true
            } else if (resultCode == Activity.RESULT_CANCELED) {
                pendingResult?.success(mapOf(
                    "isSuccessful" to false,
                    "errorMessage" to "User cancelled scanning"
                ))
                pendingResult = null
                return true
            }
        } else if (requestCode == BARCODE_SCAN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                // Get the scanned barcode results from the intent
                val barcodeValues = data.getStringArrayListExtra("barcodeValues") ?: ArrayList()
                val barcodeFormats = data.getStringArrayListExtra("barcodeFormats") ?: ArrayList()
                
                // Return result to Flutter
                pendingResult?.success(mapOf(
                    "isSuccessful" to (barcodeValues.isNotEmpty()),
                    "barcodeValues" to barcodeValues,
                    "barcodeFormats" to barcodeFormats,
                    "errorMessage" to if (barcodeValues.isEmpty()) "No barcodes detected" else null
                ))
                pendingResult = null
                return true
            } else if (resultCode == Activity.RESULT_CANCELED) {
                pendingResult?.success(mapOf(
                    "isSuccessful" to false,
                    "barcodeValues" to listOf<String>(),
                    "barcodeFormats" to listOf<String>(),
                    "errorMessage" to "User cancelled scanning"
                ))
                pendingResult = null
                return true
            }
        }
        return false
    }

    /**
     * Handles the result data from the document scanner.
     * 
     * This method extracts the scanning result from the intent and processes it
     * in a background thread to avoid blocking the UI.
     * 
     * @param data Intent containing the scan result from the document scanner activity.
     */
    private fun handleScanResult(data: Intent) {
        try {
            val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
            
            if (scanningResult == null) {
                pendingResult?.error("NO_RESULT", "Scanning completed but no result was returned", null)
                pendingResult = null
                return
            }
            
            // Process the scan result in a background thread
            executor.execute {
                processScanResult(scanningResult)
            }
        } catch (e: Exception) {
            pendingResult?.error("PROCESSING_ERROR", "Error processing scan result: ${e.message}", null)
            pendingResult = null
        }
    }

    /**
     * Processes the document scanning result, including saving images, extracting text, and generating PDF.
     * 
     * This method:
     * 1. Creates the output directory if needed
     * 2. Processes each scanned page:
     *    - Converts the image URI to a bitmap
     *    - Saves the image to the output directory
     *    - Extracts text from the image using OCR
     * 3. Generates PDF(s) from the scanned pages if requested
     * 4. Returns the results to Flutter with:
     *    - The paths to saved images or PDF(s)
     *    - Extracted text from all pages
     * 
     * @param scanningResult The result object from ML Kit document scanner containing
     *                      the scanned document pages.
     */
    private fun processScanResult(scanningResult: GmsDocumentScanningResult) {
        try {
            val pages = scanningResult.pages
            if (pages == null || pages.isEmpty()) {
                mainHandler.post {
                    pendingResult?.success(mapOf(
                        "isSuccessful" to false,
                        "errorMessage" to "No pages were scanned"
                    ))
                    pendingResult = null
                }
                return
            }

            // Create output directory if needed
            val outputDir = File(outputDirectory!!)
            if (!outputDir.exists()) {
                outputDir.mkdirs()
            }

            // Create thumbnail directory
            val thumbnailDir = File(outputDir, "thumbnails")
            if (!thumbnailDir.exists()) {
                thumbnailDir.mkdirs()
            }

            val imagePaths = mutableListOf<String>()
            val thumbnailPaths = mutableListOf<String>()
            var allText = ""
            val bitmaps = mutableListOf<Bitmap>()

            // Process each page
            pages?.forEach { page ->
                // Get the image uri and convert to bitmap
                val uri = page.imageUri
                val bitmap = getBitmapFromUri(uri)
                
                // Generate thumbnail
                val thumbnailSize = 300
                val thumbnailBitmap = Bitmap.createScaledBitmap(
                    bitmap,
                    thumbnailSize,
                    (thumbnailSize * bitmap.height / bitmap.width).toInt(),
                    true
                )
                
                // Save the image and thumbnail
                val timestamp = System.currentTimeMillis()
                val imageFile = File(outputDir, "scan_${timestamp}_${imagePaths.size}.jpg")
                val thumbnailFile = File(thumbnailDir, "scan_${timestamp}_${imagePaths.size}_thumb.jpg")
                
                saveBitmapToFile(bitmap, imageFile)
                saveBitmapToFile(thumbnailBitmap, thumbnailFile)
                
                imagePaths.add(imageFile.absolutePath)
                thumbnailPaths.add(thumbnailFile.absolutePath)
                bitmaps.add(bitmap)
                
                // Extract text
                val pageText = extractTextFromBitmap(bitmap)
                if (pageText.isNotEmpty()) {
                    if (allText.isNotEmpty()) {
                        allText += "\n\n"
                    }
                    allText += pageText
                }
                
                // Recycle thumbnails
                thumbnailBitmap.recycle()
            }
            
            // Check if PDF output was requested
            val outputFormat = currentScanArgs?.get("outputFormat") as? String
            val shouldGeneratePDF = outputFormat == "pdf"
            val shouldMergePDF = currentScanArgs?.get("mergePDF") as? Boolean ?: true

            // Return the result to Flutter
            mainHandler.post {
                val result = mutableMapOf(
                    "isSuccessful" to true,
                    "extractedText" to allText,
                    "thumbnailPaths" to thumbnailPaths
                )
                
                if (shouldGeneratePDF) {
                    if (shouldMergePDF) {
                        // Generate single PDF with all pages
                        val pdfPath = generatePDF(bitmaps, outputDir)
                        if (pdfPath != null) {
                            result["filePaths"] = listOf(pdfPath)
                        } else {
                            result["filePaths"] = imagePaths
                        }
                    } else {
                        // Generate individual PDFs for each page
                        val pdfPaths = bitmaps.mapIndexed { index, bitmap ->
                            generateSinglePagePDF(bitmap, outputDir, index)
                        }.filterNotNull()
                        
                        if (pdfPaths.isNotEmpty()) {
                            result["filePaths"] = pdfPaths
                        } else {
                            result["filePaths"] = imagePaths
                        }
                    }
                } else {
                    // Return individual image paths
                    result["filePaths"] = imagePaths
                }
                
                pendingResult?.success(result)
                pendingResult = null
            }
        } catch (e: Exception) {
            mainHandler.post {
                pendingResult?.error("PROCESSING_ERROR", "Error processing scan result: ${e.message}", null)
                pendingResult = null
            }
        }
    }
    
    /**
     * Generates a single-page PDF from a bitmap.
     * 
     * @param bitmap The bitmap to convert to PDF.
     * @param outputDir Directory where the PDF will be saved.
     * @param pageIndex Index of the page for the filename.
     * @return The path to the generated PDF file, or null if generation failed.
     */
    private fun generateSinglePagePDF(bitmap: Bitmap, outputDir: File, pageIndex: Int): String? {
        try {
            val pdfDocument = PdfDocument()
            val timestamp = System.currentTimeMillis()
            val pdfFile = File(outputDir, "scan_${timestamp}_${pageIndex}.pdf")
            
            val pageInfo = PdfDocument.PageInfo.Builder(bitmap.width, bitmap.height, 0).create()
            val page = pdfDocument.startPage(pageInfo)
            val canvas = page.canvas
            
            // Draw the bitmap on the canvas
            canvas.drawBitmap(bitmap, 0f, 0f, null)
            
            pdfDocument.finishPage(page)
            
            // Write the PDF to a file
            FileOutputStream(pdfFile).use { out ->
                pdfDocument.writeTo(out)
            }
            
            pdfDocument.close()
            return pdfFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
    
    /**
     * Generates a PDF document from an array of bitmaps.
     * 
     * This method creates a PDF document containing all the provided bitmaps,
     * with each bitmap on a separate page. The PDF is saved to the specified
     * output directory with a timestamp-based filename.
     * 
     * @param bitmaps List of Bitmap objects to include in the PDF.
     * @param outputDir Directory where the PDF will be saved.
     * @return The path to the generated PDF file, or null if generation failed.
     */
    private fun generatePDF(bitmaps: List<Bitmap>, outputDir: File): String? {
        try {
            val pdfDocument = PdfDocument()
            val timestamp = System.currentTimeMillis()
            val pdfFile = File(outputDir, "scan_${timestamp}.pdf")
            
            for (bitmap in bitmaps) {
                val pageInfo = PdfDocument.PageInfo.Builder(bitmap.width, bitmap.height, bitmaps.indexOf(bitmap)).create()
                val page = pdfDocument.startPage(pageInfo)
                val canvas = page.canvas
                
                // Draw the bitmap on the canvas
                canvas.drawBitmap(bitmap, 0f, 0f, null)
                
                pdfDocument.finishPage(page)
            }
            
            // Write the PDF to a file
            FileOutputStream(pdfFile).use { out ->
                pdfDocument.writeTo(out)
            }
            
            pdfDocument.close()
            return pdfFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
    
    /**
     * Converts a URI to a Bitmap.
     * 
     * This helper method opens an input stream from the content resolver
     * and decodes it into a Bitmap object.
     * 
     * @param uri The URI of the image to be converted.
     * @return The bitmap representation of the image.
     */
    private fun getBitmapFromUri(uri: Uri): Bitmap {
        val inputStream = context.contentResolver.openInputStream(uri)
        return BitmapFactory.decodeStream(inputStream)
    }
    
    /**
     * Saves a bitmap to a file.
     * 
     * This method compresses the bitmap as a JPEG with 80% quality
     * and writes it to the specified file.
     * 
     * @param bitmap The bitmap to save.
     * @param file The destination file where the image will be saved.
     */
    private fun saveBitmapToFile(bitmap: Bitmap, file: File) {
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
        }
    }
    
    /**
     * Asynchronously extracts text from a bitmap using coroutines.
     * 
     * This is a more elegant implementation that uses Kotlin coroutines
     * and suspending functions for cleaner asynchronous code.
     * 
     * Note: This method is included as a reference but not currently used in the active code.
     * 
     * @param bitmap The bitmap to extract text from.
     * @return The extracted text as a String.
     */
    private suspend fun extractTextFromBitmapAsync(bitmap: Bitmap): String = suspendCoroutine { continuation ->
        textRecognizer.process(bitmap, 0)
            .addOnSuccessListener { visionText ->
                continuation.resume(visionText.text)
            }
            .addOnFailureListener { e ->
                continuation.resumeWithException(e)
            }
    }
    
    /**
     * Extracts text from a bitmap using a blocking approach.
     * 
     * This method uses ML Kit's text recognition to perform OCR on the bitmap.
     * It uses a simplified blocking approach for ease of implementation.
     * 
     * @param bitmap The bitmap to extract text from.
     * @return The extracted text as a String, or an empty string if extraction fails.
     */
    private fun extractTextFromBitmap(bitmap: Bitmap): String {
        try {
            // For simplicity, we'll use a blocking approach here
            // In a production app, you might want to use coroutines
            val task = textRecognizer.process(bitmap, 0)
            var result = ""
            
            // This is a simplified approach - in production you should avoid blocking the thread
            while (!task.isComplete) {
                Thread.sleep(10)
            }
            
            if (task.isSuccessful && task.result != null) {
                result = task.result.text
            }
            
            return result
        } catch (e: Exception) {
            return ""
        }
    }

    /**
     * Called when the plugin is detached from the Flutter engine.
     * 
     * This is where we clean up resources to prevent memory leaks.
     * 
     * @param binding The binding to the Flutter engine being detached from.
     */
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    /**
     * Called when the plugin is attached to an Activity.
     * 
     * This is where we get the reference to the activity and register for activity results.
     * 
     * @param binding The binding to the Activity being attached to.
     */
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    /**
     * Called when the Activity is detached due to configuration changes.
     * 
     * This is where we clean up activity-related resources temporarily.
     */
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    /**
     * Called when the plugin is reattached to an Activity after configuration changes.
     * 
     * This is where we restore the activity reference after configuration changes.
     * 
     * @param binding The binding to the Activity being reattached to.
     */
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    /**
     * Called when the plugin is detached from the Activity.
     * 
     * This is where we clean up activity-related resources.
     */
    override fun onDetachedFromActivity() {
        activity = null
    }

    /**
     * Generates a thumbnail for a file (image or PDF)
     *
     * @param filePath Path to the file to generate thumbnail for
     * @param size Size of the thumbnail (width and height)
     * @return Path to the generated thumbnail image, or null if generation failed
     */
    private fun generateThumbnail(filePath: String, size: Int = 300): String? {
        val file = File(filePath)
        if (!file.exists()) return null

        // Create thumbnail directory if it doesn't exist
        val thumbnailDir = File(file.parent, "thumbnails")
        if (!thumbnailDir.exists()) {
            thumbnailDir.mkdirs()
        }

        // Generate thumbnail path
        val thumbnailPath = File(thumbnailDir, "${file.nameWithoutExtension}_thumb.jpg").absolutePath

        // Check if thumbnail already exists
        if (File(thumbnailPath).exists()) {
            return thumbnailPath
        }

        return try {
            if (filePath.lowercase().endsWith(".pdf")) {
                // Generate PDF thumbnail
                val fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                val pdfRenderer = PdfRenderer(fileDescriptor)
                
                try {
                    val page = pdfRenderer.openPage(0)
                    val bitmap = Bitmap.createBitmap(
                        size,
                        (size * page.height / page.width).toInt(),
                        Bitmap.Config.ARGB_8888
                    )
                    
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    page.close()
                    
                    // Save thumbnail
                    FileOutputStream(thumbnailPath).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
                    }
                    bitmap.recycle()
                    
                    thumbnailPath
                } finally {
                    pdfRenderer.close()
                    fileDescriptor.close()
                }
            } else {
                // Generate image thumbnail
                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeFile(filePath, options)
                
                val width = options.outWidth
                val height = options.outHeight
                val scale = minOf(size.toFloat() / width, size.toFloat() / height)
                
                options.inJustDecodeBounds = false
                options.inSampleSize = (1 / scale).toInt()
                
                val bitmap = BitmapFactory.decodeFile(filePath, options)
                
                // Save thumbnail
                FileOutputStream(thumbnailPath).use { out ->
                    bitmap?.compress(Bitmap.CompressFormat.JPEG, 80, out)
                }
                bitmap?.recycle()
                
                thumbnailPath
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    companion object {
        /**
         * Request code for document scanning activity.
         */
        private const val DOCUMENT_SCAN_REQUEST_CODE = 100
        
        /**
         * Request code for barcode scanning activity.
         */
        private const val BARCODE_SCAN_REQUEST_CODE = 101
    }
} 