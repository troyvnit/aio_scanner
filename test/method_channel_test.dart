import 'package:aio_scanner/aio_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('aio_scanner');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        log.add(methodCall);
        
        // Provide mock responses based on method name
        switch (methodCall.method) {
          case 'isDocumentScanningSupported':
            return true;
          case 'startDocumentScanning':
            return {
              'isSuccessful': true,
              'imagePaths': ['/mock/doc1.jpg', '/mock/doc2.jpg'],
              'extractedText': 'Mock document text',
              'errorMessage': null,
            };
          case 'startBusinessCardScanning':
            return {
              'isSuccessful': true,
              'imagePaths': ['/mock/card.jpg'],
              'extractedText': 'Mock business card text',
              'errorMessage': null,
            };
          default:
            return null;
        }
      },
    );
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  test('platform channel calls are made with correct method names', () async {
    // Test isDocumentScanningSupported
    await AioScanner.isDocumentScanningSupported();
    expect(log.last.method, 'isDocumentScanningSupported');
    
    // Test startDocumentScanning
    await AioScanner.startDocumentScanning(outputDirectory: '/test/dir');
    expect(log.last.method, 'startDocumentScanning');
    
    // Test startBusinessCardScanning
    await AioScanner.startBusinessCardScanning(outputDirectory: '/test/cards');
    expect(log.last.method, 'startBusinessCardScanning');
    
    // Verify the correct number of calls
    expect(log.length, 3);
  });

  test('document scanning arguments are passed correctly', () async {
    await AioScanner.startDocumentScanning(
      outputDirectory: '/test/documents',
      maxNumPages: 10,
      initialMessage: 'Custom initial message',
      scanningMessage: 'Custom scanning message',
      allowGalleryImport: false,
    );
    
    final MethodCall call = log.last;
    expect(call.method, 'startDocumentScanning');
    
    final Map<String, dynamic> args = call.arguments as Map<String, dynamic>;
    expect(args['outputDirectory'], '/test/documents');
    expect(args['maxNumPages'], 10);
    expect(args['initialMessage'], 'Custom initial message');
    expect(args['scanningMessage'], 'Custom scanning message');
    expect(args['allowGalleryImport'], false);
  });

  test('business card scanning arguments are passed correctly', () async {
    await AioScanner.startBusinessCardScanning(
      outputDirectory: '/test/business_cards',
      initialMessage: 'Custom card message',
      scanningMessage: 'Custom card scanning',
    );
    
    final MethodCall call = log.last;
    expect(call.method, 'startBusinessCardScanning');
    
    final Map<String, dynamic> args = call.arguments as Map<String, dynamic>;
    expect(args['outputDirectory'], '/test/business_cards');
    expect(args['initialMessage'], 'Custom card message');
    expect(args['scanningMessage'], 'Custom card scanning');
  });

  test('document scanning returns processed ScanResult', () async {
    final result = await AioScanner.startDocumentScanning(
      outputDirectory: '/test/output',
    );
    
    expect(result, isNotNull);
    expect(result!.isSuccessful, true);
    expect(result.scannedImages.length, 2);
    expect(result.scannedImages[0].path, '/mock/doc1.jpg');
    expect(result.scannedImages[1].path, '/mock/doc2.jpg');
    expect(result.extractedText, 'Mock document text');
    expect(result.errorMessage, isNull);
  });

  test('business card scanning returns processed ScanResult', () async {
    final result = await AioScanner.startBusinessCardScanning(
      outputDirectory: '/test/cards',
    );
    
    expect(result, isNotNull);
    expect(result!.isSuccessful, true);
    expect(result.scannedImages.length, 1);
    expect(result.scannedImages[0].path, '/mock/card.jpg');
    expect(result.extractedText, 'Mock business card text');
    expect(result.errorMessage, isNull);
  });
  
  test('handle platform exceptions properly', () async {
    // Set a mock handler that throws exceptions
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        log.add(methodCall);
        throw PlatformException(
          code: 'TEST_ERROR',
          message: 'Test platform exception',
          details: 'Detailed error info',
        );
      },
    );
    
    // Test isDocumentScanningSupported with exception
    final supportResult = await AioScanner.isDocumentScanningSupported();
    expect(supportResult, false);
    
    // Test document scanning with exception
    final scanResult = await AioScanner.startDocumentScanning(outputDirectory: '/test/dir');
    expect(scanResult!.isSuccessful, false);
    expect(scanResult.errorMessage, contains('Test platform exception'));
    
    // Test business card scanning with exception
    final cardResult = await AioScanner.startBusinessCardScanning(outputDirectory: '/test/cards');
    expect(cardResult!.isSuccessful, false);
    expect(cardResult.errorMessage, contains('Test platform exception'));
  });
} 