package com.troyvnit.aio_scanner

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Activity for real-time barcode scanning using CameraX and ML Kit.
 *
 * This activity provides a camera preview and continuously analyzes frames
 * to detect barcodes. Once a barcode is detected, it presents the data to the user
 * and provides options to accept or continue scanning.
 */
class BarcodeScannerActivity : AppCompatActivity() {
    private lateinit var cameraProviderFuture: ListenableFuture<ProcessCameraProvider>
    private lateinit var previewView: PreviewView
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var barcodeScanner: BarcodeScanner
    private lateinit var barcodeFormats: ArrayList<String>
    private var camera: Camera? = null
    
    // Result data
    private val detectedBarcodeValues = ArrayList<String>()
    private val detectedBarcodeFormats = ArrayList<String>()
    
    // UI elements
    private lateinit var flashButton: ImageButton
    
    // State management
    private var isFlashEnabled = false
    private var isScanning = true
    
    companion object {
        private const val TAG = "BarcodeScannerActivity"
        private const val CAMERA_PERMISSION_REQUEST_CODE = 100
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set up the layout
        setContentView(R.layout.activity_barcode_scanner)
        
        // Initialize UI elements
        previewView = findViewById(R.id.preview_view)
        flashButton = findViewById(R.id.flash_button)
        
        // Get barcode formats from intent
        barcodeFormats = intent.getStringArrayListExtra("barcodeFormats") ?: arrayListOf()
        
        // Set up the barcode scanner with options
        val options = createBarcodeScannerOptions()
        barcodeScanner = BarcodeScanning.getClient(options)
        
        // Set up button click listeners
        flashButton.setOnClickListener {
            toggleFlash()
        }
        
        // Initialize the camera executor
        cameraExecutor = Executors.newSingleThreadExecutor()
        
        // Request camera permissions if needed, otherwise start camera
        if (hasCameraPermission()) {
            startCamera()
        } else {
            requestCameraPermission()
        }
    }
    
    /**
     * Creates barcode scanner options based on requested formats.
     */
    private fun createBarcodeScannerOptions(): BarcodeScannerOptions {
        if (barcodeFormats.isEmpty()) {
            return BarcodeScannerOptions.Builder()
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
            
            return BarcodeScannerOptions.Builder()
                .setBarcodeFormats(formatFlags)
                .build()
        }
    }
    
    /**
     * Sets up the camera with CameraX.
     */
    private fun startCamera() {
        cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        
        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                
                // Set up the preview use case
                val preview = Preview.Builder().build()
                preview.setSurfaceProvider(previewView.surfaceProvider)
                
                // Set up the image analysis use case
                val imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    
                imageAnalysis.setAnalyzer(cameraExecutor, BarcodeAnalyzer())
                
                // Select back camera
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                
                // Unbind all use cases before rebinding
                cameraProvider.unbindAll()
                
                // Bind use cases to camera
                camera = cameraProvider.bindToLifecycle(
                    this, cameraSelector, preview, imageAnalysis)
                
                // Enable flash button
                flashButton.visibility = View.VISIBLE
                
            } catch (e: Exception) {
                Log.e(TAG, "Use case binding failed", e)
                Toast.makeText(this, "Failed to start camera: ${e.message}", Toast.LENGTH_LONG).show()
                setResult(RESULT_CANCELED)
                finish()
            }
            
        }, ContextCompat.getMainExecutor(this))
    }
    
    /**
     * Toggles the camera flash.
     */
    private fun toggleFlash() {
        camera?.let {
            try {
                isFlashEnabled = !isFlashEnabled
                it.cameraControl.enableTorch(isFlashEnabled)
                
                // Update flash button icon
                flashButton.setImageResource(
                    if (isFlashEnabled) R.drawable.ic_flash_on
                    else R.drawable.ic_flash_off
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to toggle flash", e)
            }
        }
    }
    
    /**
     * Checks if the app has camera permissions.
     */
    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }
    
    /**
     * Requests camera permissions from the user.
     */
    private fun requestCameraPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST_CODE
        )
    }
    
    /**
     * Handles permission request results.
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERMISSION_REQUEST_CODE && grantResults.isNotEmpty()) {
            if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera()
            } else {
                Toast.makeText(this, "Camera permission is required for barcode scanning", Toast.LENGTH_LONG).show()
                setResult(RESULT_CANCELED)
                finish()
            }
        }
    }
    
    /**
     * Analyzer class for processing camera frames to detect barcodes.
     */
    private inner class BarcodeAnalyzer : ImageAnalysis.Analyzer {
        override fun analyze(imageProxy: ImageProxy) {
            val mediaImage = imageProxy.image
            if (mediaImage != null && isScanning) {
                val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                
                barcodeScanner.process(image)
                    .addOnSuccessListener { barcodes ->
                        if (barcodes.isNotEmpty() && isScanning) {
                            // Stop scanning temporarily
                            isScanning = false
                            
                            // Process detected barcodes
                            val barcode = barcodes[0] // Take the first barcode found
                            barcode.rawValue?.let { value ->
                                // Get barcode format name
                                val format = getBarcodeFormatName(barcode.format)
                                
                                // Add to results
                                detectedBarcodeValues.add(value)
                                detectedBarcodeFormats.add(format)
                                
                                // Auto-finish
                                finishWithResult()
                            }
                        }
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Barcode scanning failed", e)
                    }
                    .addOnCompleteListener {
                        // Close the image regardless of success or failure
                        imageProxy.close()
                    }
            } else {
                // Close the image if we're not scanning
                imageProxy.close()
            }
        }
        
        /**
         * Gets a string representation of a barcode format code.
         */
        private fun getBarcodeFormatName(format: Int): String {
            return when (format) {
                Barcode.FORMAT_QR_CODE -> "qr"
                Barcode.FORMAT_CODE_128 -> "code128"
                Barcode.FORMAT_CODE_39 -> "code39"
                Barcode.FORMAT_CODE_93 -> "code93"
                Barcode.FORMAT_EAN_8 -> "ean8"
                Barcode.FORMAT_EAN_13 -> "ean13"
                Barcode.FORMAT_UPC_A, Barcode.FORMAT_UPC_E -> "upc"
                Barcode.FORMAT_PDF417 -> "pdf417"
                Barcode.FORMAT_AZTEC -> "aztec"
                Barcode.FORMAT_DATA_MATRIX -> "datamatrix"
                Barcode.FORMAT_ITF -> "itf"
                else -> "unknown"
            }
        }
    }
    
    /**
     * Finishes the activity and returns the barcode results.
     */
    private fun finishWithResult() {
        val resultIntent = Intent()
        resultIntent.putStringArrayListExtra("barcodeValues", detectedBarcodeValues)
        resultIntent.putStringArrayListExtra("barcodeFormats", detectedBarcodeFormats)
        setResult(RESULT_OK, resultIntent)
        finish()
    }
    
    /**
     * Handles back button press.
     */
    override fun onBackPressed() {
        // Cancel scanning and return
        setResult(RESULT_CANCELED)
        finish()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
} 