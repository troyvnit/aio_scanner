# Changelog

All notable changes to the AIO Scanner Flutter plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2024-03-17

This release adds PDF support to the AIO Scanner plugin with the following features:

- PDF generation from scanned documents
- Support for both single-page and multi-page PDF output
- Option to merge multiple pages into a single PDF
- PDF sharing functionality using SharePlus
- Enhanced error handling and user feedback
- Improved test coverage and reliability

### Added
- PDF generation from scanned documents
- Support for single and multi-page PDF output
- PDF sharing functionality using SharePlus

### Changed
- Replaced URL launcher with SharePlus for better PDF handling
- Improved error messages for PDF operations
- Enhanced UI with bottom sheet for output format selection
- Fixed SnackBar positioning issues

### Fixed
- Fixed PDF opening functionality
- Fixed SnackBar visibility issues with FAB
- Improved error handling for file operations

### Improved
- Enhanced test coverage for platform exceptions
- Added comprehensive error handling tests for document scanning
- Added comprehensive error handling tests for barcode scanning
- Improved test reliability by handling directory-related failures

## [1.0.0] - 2024-03-17

Initial release of the AIO Scanner plugin with the following features:

- Document scanning with automatic edge detection
- Barcode scanning for multiple formats (QR, EAN, Code128, etc.)
- Text extraction from scanned documents using OCR
- Support for both iOS and Android platforms
- Configurable output formats (images)
- Permission handling for camera and storage access
- Example app demonstrating all features

### Added
- Initial package structure
- Document scanning with edge detection
- Barcode scanning with real-time detection
- Text extraction (OCR) functionality
- Support for iOS (VisionKit 16.0+) and Android (ML Kit)
- Auto-confirmation for detected barcodes
- Integrated flash control
- Example app demonstrating key features
- Comprehensive README with usage examples
- Support for multiple pages in document scanner
- Gallery image import capability
- Permission handling for Android 10+ and iOS
- Proper handling of swipe-down dismissal on iOS
- Clean icon button UI for flash control on Android

### Improved
- Direct bitmap processing for Android barcode scanning
- Optimized scanning performance and UI responsiveness
- Memory management and resource cleanup

## [0.0.1] - 2025-03-15

### Added
- Initial development release

<!-- 
## [x.x.x] - YYYY-MM-DD

### Added
- Feature X
- Feature Y

### Changed
- Improved Z

### Fixed
- Bug in component A
-->
