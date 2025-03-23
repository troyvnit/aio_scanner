import 'dart:io';

import 'package:aio_scanner/aio_scanner.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
/// 2. Initiating business card scanning
/// 3. Displaying scanned document images
/// 4. Showing extracted text from scanned documents
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Collection of scanned document images
  final List<File> _scannedImages = [];

  /// Text extracted from scanned documents using OCR
  String _extractedText = '';

  /// Loading state to manage UI during scanning operations
  bool _isLoading = false;

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
      // Get Android SDK version using device_info_plus
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      final bool isAndroid13OrHigher = sdkVersion >= 33; // SDK 33 = Android 13
      final bool isAndroid10OrHigher = sdkVersion >= 29; // SDK 29 = Android 10

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
                      onTap: _startDocumentScan,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      title: 'Business Card Scanner',
                      description: 'Scan and extract text from business cards',
                      icon: Icons.contact_mail,
                      onTap: _startBusinessCardScan,
                    ),

                    // Results section
                    if (_scannedImages.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Scanned Images',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _scannedImages.length,
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
                                    _scannedImages[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
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
                      ),
                    ],

                    // Extracted text section
                    if (_extractedText.isNotEmpty) ...[
                      const SizedBox(height: 32),
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
                ),
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
      });

      // Call the plugin
      ScanResult? result = await AioScanner.startDocumentScanning(
        maxNumPages: 5,
        initialMessage: 'Position document in frame',
        scanningMessage: 'Hold still...',
        allowGalleryImport: true,
      );

      setState(() {
        _isLoading = false;
      });

      if (result != null && result.isSuccessful) {
        // Process scan result
        setState(() {
          _scannedImages.clear();
          _scannedImages.addAll(result.scannedImages);
          _extractedText = result.extractedText ?? '';
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

  /// Initiates the business card scanning process
  ///
  /// This method:
  /// 1. Shows a loading indicator
  /// 2. Creates an output directory for saving scanned business cards
  /// 3. Launches the business card scanner
  /// 4. Processes the scan results, displaying the card image and extracted text
  /// 5. Handles errors and cancellations
  ///
  /// The business card scanner is optimized for the smaller format of business cards
  /// and focuses on extracting contact information using OCR.
  Future<void> _startBusinessCardScan() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Call the plugin
      ScanResult? result = await AioScanner.startBusinessCardScanning(
        initialMessage: 'Position card in frame',
        scanningMessage: 'Capturing...',
      );

      setState(() {
        _isLoading = false;
      });

      if (result != null && result.isSuccessful) {
        // Process scan result
        setState(() {
          _scannedImages.clear();
          _scannedImages.addAll(result.scannedImages);
          _extractedText = result.extractedText ?? '';
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
      ),
    );
  }
}
