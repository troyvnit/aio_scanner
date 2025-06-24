# Changelog

## 1.0.3 - 2025-06-24

- **FIX**: Resolve conflicting FileOutputStream import in Android Kotlin code ([#1](https://github.com/troyvnit/aio_scanner/issues/1))
- **FIX**: Remove duplicate import statement causing compilation errors ([#2](https://github.com/troyvnit/aio_scanner/issues/2))

## 1.0.2 - 2025-06-01

- **FEAT**: Result now should be `ScanFile` class with `filePath` and `thumbnailPath`
- **FEAT**: Updated example app to show file information with thumbnails
- **TEST**: Improved test coverage and fixed test cases

## 1.0.1 - 2025-05-11

- **FEAT**: Add PDF generation from scanned documents
- **FEAT**: Add support for single and multi-page PDF output
- **FEAT**: Add PDF sharing functionality using SharePlus
- **FEAT**: Add bottom sheet for output format selection
- **FIX**: Replace URL launcher with SharePlus for better PDF handling
- **FIX**: Fix PDF opening functionality
- **FIX**: Fix SnackBar visibility issues with FAB
- **FIX**: Fix error handling for file operations
- **TEST**: Add comprehensive error handling tests
- **TEST**: Improve test reliability by handling directory-related failures

## 1.0.0 - 2025-03-23

- **FEAT**: Add document scanning with edge detection
- **FEAT**: Add barcode scanning with real-time detection
- **FEAT**: Add text extraction (OCR) functionality
- **FEAT**: Add support for iOS (VisionKit 16.0+) and Android (ML Kit)
- **FEAT**: Add auto-confirmation for detected barcodes
- **FEAT**: Add integrated flash control
- **FEAT**: Add example app demonstrating key features
- **FEAT**: Add support for multiple pages in document scanner
- **FEAT**: Add gallery image import capability
- **FEAT**: Add permission handling for Android 10+ and iOS
- **FEAT**: Add proper handling of swipe-down dismissal on iOS
- **FEAT**: Add clean icon button UI for flash control on Android
- **PERF**: Optimize scanning performance and UI responsiveness
- **PERF**: Improve memory management and resource cleanup

## 0.0.1 - 2025-03-22

- **FEAT**: Initial development release
