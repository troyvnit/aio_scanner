import 'dart:io';

import 'package:aio_scanner/aio_scanner.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

/// Application entry point
void main() {
  runApp(const MyApp());
}

/// Root application widget
///
/// Sets up the MaterialApp with theme configuration and routes.
/// The app uses Material 3 design with a deep purple seed color.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIO Scanner Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Main screen that showcases the AioScanner functionality
///
/// This screen provides UI for:
/// 1. Initiating document scanning
/// 2. Initiating barcode scanning
/// 3. Displaying scanned document images or barcodes
/// 4. Showing extracted text or barcode values
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Collection of scanned document files
  final List<File> _scannedFiles = [];

  /// Text extracted from scanned documents using OCR
  String _extractedText = '';

  /// List of decoded barcode values
  List<String> _barcodeValues = [];

  /// List of barcode formats detected
  List<String> _barcodeFormats = [];

  /// Loading state to manage UI during scanning operations
  bool _isLoading = false;

  /// Current scan mode (document or barcode)
  String _currentScanMode = 'document';

  /// Current output format for document scanning
  ScanOutputFormat _outputFormat = ScanOutputFormat.image;

  @override
  void initState() {
    super.initState();
    // Request necessary permissions when the app starts
    _requestPermissions();
  }

  /// Requests camera and storage permissions required for document scanning
  ///
  /// This method adapts to the Android version:
  /// - For Android 13+ (API 33+): Requests Camera and READ_MEDIA_IMAGES permissions
  /// - For Android 10-12 (API 29-32): Requests Camera and STORAGE permissions
  /// - For Android < 10 (API < 29): Requests Camera and STORAGE permissions
  ///
  /// Displays an error message if any permission is denied.
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Get Android SDK version directly from the Platform info
      // Android SDK version naming: Android 13 = SDK 33, Android 12 = SDK 32, etc.
      final androidVersion =
          int.tryParse(Platform.operatingSystemVersion.split('.').first) ?? 0;
      final bool isAndroid13OrHigher = androidVersion >= 13; // SDK 33+
      final bool isAndroid10OrHigher = androidVersion >= 10; // SDK 29+

      // Determine which permissions to request based on Android version
      final permissionsToRequest = <Permission>[
        Permission.camera,
        if (isAndroid13OrHigher)
          // Android 13+ uses more granular storage permissions
          Permission.photos
        else if (isAndroid10OrHigher)
          // Android 10-12 uses general storage permission but with scoped storage
          Permission.storage
        else
          // Android < 10 uses general storage permission
          Permission.storage,
      ];

      // Request all required permissions
      final statuses = await permissionsToRequest.request();

      // Check if any permission was denied
      if (statuses.values.any(
        (status) => status.isDenied || status.isPermanentlyDenied,
      )) {
        _showErrorSnackBar(
          'Camera and storage permissions are required for document scanning. '
          'Please enable them in app settings.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIO Scanner'),
        centerTitle: true,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Scan buttons
                    const SizedBox(height: 24),
                    _buildFeatureCard(
                      title: 'Document Scanner',
                      description:
                          'Scan documents with automatic edge detection',
                      icon: Icons.document_scanner,
                      onTap: () {
                        _showOutputFormatBottomSheet();
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      title: 'Barcode Scanner',
                      description: 'Scan QR codes and barcodes',
                      icon: Icons.qr_code_scanner,
                      onTap: _startBarcodeScan,
                    ),

                    // Document scan results
                    if (_currentScanMode == 'document' &&
                        _scannedFiles.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Scanned Documents',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_outputFormat == ScanOutputFormat.image)
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _scannedFiles.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 200,
                                    width: 150,
                                    color: Colors.grey.shade300,
                                    child: Image.file(
                                      _scannedFiles[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Center(
                                          child: Icon(
                                            Icons.image,
                                            size: 80,
                                            color: Colors.grey.shade600,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _openPDF,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Open PDF'),
                        ),

                      // Document extracted text
                      if (_extractedText.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Extracted Text',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(_extractedText),
                        ),
                      ],
                    ],

                    // Barcode scan results
                    if (_currentScanMode == 'barcode' &&
                        _barcodeValues.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Scanned Barcodes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // List of detected barcodes
                      ...List.generate(_barcodeValues.length, (index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.deepPurple.shade100,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _barcodeFormats[index].toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.deepPurple.shade800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () {
                                      // Copy to clipboard functionality could be added here
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Copied to clipboard'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    tooltip: 'Copy to clipboard',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _barcodeValues[index],
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _currentScanMode == 'document'
                ? _startDocumentScan
                : _startBarcodeScan,
        tooltip: 'Start Scan',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  /// Builds a feature card UI component for scanner options
  ///
  /// Creates a visually appealing card that represents a scanning feature
  /// with an icon, title, description, and tap functionality.
  ///
  /// Parameters:
  /// - [title]: The name of the scanning feature
  /// - [description]: A brief explanation of the feature
  /// - [icon]: The icon representing the feature
  /// - [onTap]: The callback function to execute when the card is tapped
  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(icon, color: Colors.deepPurple, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Initiates the document scanning process
  ///
  /// This method:
  /// 1. Shows a loading indicator
  /// 2. Creates an output directory for saving scanned images
  /// 3. Launches the document scanner
  /// 4. Processes the scan results, displaying images and extracted text
  /// 5. Handles errors and cancellations
  ///
  /// The document scanner supports multiple pages (up to 5) and can
  /// extract text from all pages using OCR.
  Future<void> _startDocumentScan() async {
    try {
      setState(() {
        _isLoading = true;
        _currentScanMode = 'document';
      });

      // Check if document scanning is supported
      final isSupported = await AioScanner.isDocumentScanningSupported();
      if (!isSupported) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Document scanning is not supported on this device');
        return;
      }

      // Call the plugin
      ScanResult? result = await AioScanner.startDocumentScanning(
        maxNumPages: 5,
        initialMessage: 'Position document in frame',
        scanningMessage: 'Hold still...',
        allowGalleryImport: true,
        outputFormat: _outputFormat,
      );

      setState(() {
        _isLoading = false;
      });

      if (result != null && result.isSuccessful) {
        // Process scan result
        setState(() {
          _scannedFiles.clear();
          _scannedFiles.addAll(result.scannedFiles);
          _extractedText = result.extractedText ?? '';
          _barcodeValues = [];
          _barcodeFormats = [];
        });
      } else {
        _showErrorSnackBar(
          'Scanning cancelled or failed: ${result?.errorMessage ?? "Unknown error"}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  /// Initiates the barcode scanning process
  ///
  /// This method:
  /// 1. Shows a loading indicator
  /// 2. Checks if barcode scanning is supported
  /// 3. Launches the barcode scanner
  /// 4. Processes the scan results, displaying barcode values and formats
  /// 5. Handles errors and cancellations
  ///
  /// The barcode scanner can detect multiple barcode formats including
  /// QR codes, Code 128, EAN, UPC, and more.
  Future<void> _startBarcodeScan() async {
    try {
      setState(() {
        _isLoading = true;
        _currentScanMode = 'barcode';
      });

      // Check if barcode scanning is supported
      final isSupported = await AioScanner.isBarcodeScanningSupported();
      if (!isSupported) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Barcode scanning is not supported on this device');
        return;
      }

      // Call the plugin
      BarcodeScanResult? result = await AioScanner.startBarcodeScanning(
        scanningMessage: 'Scanning...',
        recognizedFormats: ['qr', 'ean13', 'code128'],
      );

      setState(() {
        _isLoading = false;
      });

      if (result != null && result.isSuccessful) {
        // Process scan result
        setState(() {
          _barcodeValues = result.barcodeValues;
          _barcodeFormats = result.barcodeFormats;
          _scannedFiles.clear();
          _extractedText = '';
        });
      } else {
        _showErrorSnackBar(
          'Scanning cancelled or failed: ${result?.errorMessage ?? "Unknown error"}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  /// Displays an error message using a SnackBar
  ///
  /// Provides user feedback when an operation fails or permissions are denied.
  /// Uses a floating red SnackBar for high visibility.
  ///
  /// Parameter:
  /// - [message]: The error message to display
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  Future<void> _openPDF() async {
    if (_scannedFiles.isEmpty) {
      _showErrorSnackBar('No scanned files available');
      return;
    }

    final file = _scannedFiles.first;
    if (!await file.exists()) {
      _showErrorSnackBar('PDF file not found at: ${file.path}');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Scanned Document',
          files: _scannedFiles.map((file) => XFile(file.path)).toList(),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to share PDF: ${e.toString()}');
    }
  }

  void _showOutputFormatBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Scan as Images'),
                subtitle: const Text('Save each page as a separate image'),
                selected: _outputFormat == ScanOutputFormat.image,
                onTap: () {
                  setState(() {
                    _outputFormat = ScanOutputFormat.image;
                  });
                  Navigator.pop(context);
                  _startDocumentScan();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Scan as PDF'),
                subtitle: const Text('Save all pages as a single PDF'),
                selected: _outputFormat == ScanOutputFormat.pdf,
                onTap: () {
                  setState(() {
                    _outputFormat = ScanOutputFormat.pdf;
                  });
                  Navigator.pop(context);
                  _startDocumentScan();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
