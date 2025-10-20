import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const DimensionCaptureApp());
}

class DimensionCaptureApp extends StatelessWidget {
  const DimensionCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DimensionCaptureHome(),
      theme: ThemeData(
        primarySwatch: Colors.yellow,
      ),
    );
  }
}

class DimensionCaptureHome extends StatefulWidget {
  const DimensionCaptureHome({super.key});

  @override
  _DimensionCaptureHomeState createState() => _DimensionCaptureHomeState();
}

class _DimensionCaptureHomeState extends State<DimensionCaptureHome> {
  final ImagePicker _picker = ImagePicker();
  XFile? _originalImage;
  String? _processedImageBase64;
  bool _isLoading = false;
  String? _message;
  List<dynamic> _objectMeasurements = [];

  Future<void> _processImage(XFile imageFile) async {
    setState(() {
      _isLoading = true;
      _processedImageBase64 = null;
      _objectMeasurements = [];
    });

    try {
      var formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path, 
          filename: 'image.png'
        ),
      });
      
      Dio dio = Dio(BaseOptions(
        connectTimeout: Duration(seconds: 100),
        receiveTimeout: Duration(seconds: 100),
        sendTimeout: Duration(seconds: 100),
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          "Connection": "Keep-Alive",
          "Keep-Alive": "timeout=10, max=1000"
        }
      ));

      var response = await dio.post(
        'http://192.168.17.97:5000/process-image/', 
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (status) => status! < 500
        )
      );
      
      if (response.statusCode == 200) {
        dynamic processedImage = response.data['processed_image'];
        
        if (processedImage == null || processedImage.isEmpty) {
          throw Exception('No processed image received');
        }

        setState(() {
          _originalImage = imageFile;
          _processedImageBase64 = processedImage;
          _objectMeasurements = response.data['object_measurements'] ?? [];
          _message = 'Detected ${_objectMeasurements.length} objects.';
          _isLoading = false;
        });
      } else {
        String errorMessage = response.data['error'] ?? 'Unknown server error';
        _showErrorSnackBar('Error: $errorMessage');
        
        setState(() {
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      String errorMessage = _handleDioError(e);
      _showErrorSnackBar(errorMessage);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar("Unexpected error: $e");
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.sendTimeout:
        return 'Send timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.badResponse:
        return 'Bad server response';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.unknown:
        return e.error is SocketException 
          ? 'Network error. Check your connection.' 
          : 'Unexpected network error';
      default:
        return 'Unexpected error: ${e.message}';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        await _processImage(image);
      }
    } catch (e) {
      print("Error picking image: $e");
      _showErrorSnackBar("Error picking image");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DimensionCapture'),
        backgroundColor: Colors.yellow[700],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInstructionSection(),
              const SizedBox(height: 20),
              _buildImagePickButtons(),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
              _buildImageDisplay(),
              const SizedBox(height: 20),
              _buildMeasurementTable(),
            ],
      ),
    ),
  ),
);
  }

  Widget _buildMeasurementTable() {
    if (_objectMeasurements.isEmpty) {
      return Container(); // Return empty container if no measurements
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Object Measurements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.yellow[800],
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => Colors.yellow.shade100
                ),
                columns: const [
                  DataColumn(label: Text('Objects', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Length (cm)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Width (cm)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _objectMeasurements.map((measurement) {
                  return DataRow(cells: [
                    DataCell(Text('${' ${(_objectMeasurements.indexOf(measurement) == 0)?'Aruko': _objectMeasurements.indexOf(measurement)}'}')),
                    DataCell(Text('${measurement['length']}')),
                    DataCell(Text('${measurement['width']}')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Measurement Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.yellow[800],
              ),
            ),
            const SizedBox(height: 10),
            _buildInstructionStep(
              '1. Print ArUco Marker',
              'Print a 5cm x 5cm ArUco marker to ensure accurate measurements.',
            ),
            const SizedBox(height: 10),
            _buildInstructionStep(
              '2. Position Marker',
              'Place the printed ArUco marker next to the object you want to measure.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, color: Colors.yellow[700], size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16
                ),
              ),
              const SizedBox(height: 5),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Gallery'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Camera'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageDisplay() {
    return Column(
      children: [
        if (_originalImage != null)
          _buildImageCard('Original Image', Image.file(File(_originalImage!.path))),
        const SizedBox(height: 10),
        if (_processedImageBase64 != null)
          _buildImageCard(
            'Processed Image', 
            Image.memory(
              base64Decode(_processedImageBase64!),
              width: double.infinity,
              fit: BoxFit.contain,
              height: 250,
            )
          ),
      ],
    );
  }

  Widget _buildImageCard(String title, Widget imageWidget) {
    return Card(
      elevation: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16
              ),
            ),
          ),
          imageWidget,
        ],
      ),
    );
  }
}