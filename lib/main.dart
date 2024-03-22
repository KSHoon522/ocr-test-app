import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:ocr_test_app/screens/ResultList.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:ocr_test_app/screens/result.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = [];
const apiKey = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메인 화면')),
      body: const Center(child: Text('Floating 버튼을 눌러 카메라를 실행하세요.')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraScreen()),
          );
        },
        child: const Icon(Icons.camera_alt),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 4.0,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ResultsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  /* Future<void> takePicture() async {
    if (!controller!.value.isInitialized) {
      print("Controller is not initialized");
      return;
    }

    var image = await controller!.takePicture();
    await sendImageToAPI(File(image.path));
  } */
  Future<void> takePicture() async {
    if (!controller!.value.isInitialized) {
      print("Controller is not initialized");
      return;
    }

    // 사진 찍기
    final image = await controller!.takePicture();

    // 이미지 파일을 불러옴
    final originalImage = img.decodeImage(File(image.path).readAsBytesSync());

    if (originalImage != null) {
      // 가이드에 맞춰 이미지를 자름
      // 예시에서는 이미지의 중앙 80%를 자르는 것으로 가정
      final startX = (originalImage.width * 0.1).round();
      final startY = (originalImage.height * 0.1).round();
      final width = (originalImage.width * 0.8).round();
      final height = (originalImage.height * 0.8).round();

      final croppedImage = img.copyCrop(originalImage,
          x: startX, y: startY, width: width, height: height);

      // 잘린 이미지를 새 파일에 저장
      final croppedFilePath =
          '${(await getTemporaryDirectory()).path}/cropped.png';
      final croppedFile = File(croppedFilePath)
        ..writeAsBytesSync(img.encodePng(croppedImage));

      // 잘린 이미지를 API에 보냄
      await sendImageToAPI(croppedFile);
    }
  }

  Future<void> sendImageToAPI(File imagePath) async {
    var uri = Uri.parse('https://api.upstage.ai/v1/document-ai/ocr');
    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..files
          .add(await http.MultipartFile.fromPath('document', imagePath.path));

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseData = await response.stream.toBytes();
      var responseString = utf8.decode(responseData);
      var jsonResponse = jsonDecode(responseString);
      if (!mounted) return;
      saveResult(jsonResponse);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OCRResultScreen(result: jsonResponse),
        ),
      );
    } else {
      print('OCR 처리 실패');
    }
  }

  Future<void> saveResult(Map<String, dynamic> result) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? results = prefs.getStringList('ocrResults');
    List resultList = results != null
        ? results.map((result) => jsonDecode(result)).toList()
        : [];
    resultList.add(result);
    await prefs.setStringList(
        'ocrResults', resultList.map((result) => jsonEncode(result)).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (!controller!.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('카메라')),
      body: Column(
        children: [
          Expanded(
            // LayoutBuilder를 Expanded로 감싸서 크기 제한
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double statusBarHeight =
                      MediaQuery.of(context).padding.top;
                  final double appBarHeight =
                      kToolbarHeight + MediaQuery.of(context).padding.top;
                  final double availableHeight = constraints.maxHeight -
                      appBarHeight -
                      statusBarHeight -
                      20;
                  return Stack(
                    children: <Widget>[
                      CameraPreview(controller!), // 카메라 프리뷰
                      CustomPaint(
                        size: Size(constraints.maxWidth,
                            availableHeight), // LayoutBuilder 제약을 사용
                        painter: GuidePainter(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Center(
            child: ElevatedButton(
              onPressed: () async {
                await takePicture();
              },
              child: const Icon(Icons.camera),
            ),
          ),
        ],
      ),
    );
  }
}

// 가이드를 그리는 CustomPainter 클래스
class GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(size.width * 0.1, size.height * 0.1,
        size.width * 0.8, size.height * 0.8);
    final Paint dimPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final Paint clearPaint = Paint()..blendMode = BlendMode.clear;
    final Paint linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;

    // 어두운 배경 그리기
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
    // 밝은 영역 만들기
    canvas.drawRect(rect, clearPaint);

    // 모서리에 선 그리기
    const double cornerLength = 20; // 모서리 선의 길이
    // 왼쪽 상단 모서리
    canvas.drawLine(
        rect.topLeft, rect.topLeft + const Offset(cornerLength, 0), linePaint);
    canvas.drawLine(
        rect.topLeft, rect.topLeft + const Offset(0, cornerLength), linePaint);
    // 오른쪽 상단 모서리
    canvas.drawLine(rect.topRight,
        rect.topRight - const Offset(cornerLength, 0), linePaint);
    canvas.drawLine(rect.topRight,
        rect.topRight + const Offset(0, cornerLength), linePaint);
    // 왼쪽 하단 모서리
    canvas.drawLine(rect.bottomLeft,
        rect.bottomLeft + const Offset(cornerLength, 0), linePaint);
    canvas.drawLine(rect.bottomLeft,
        rect.bottomLeft - const Offset(0, cornerLength), linePaint);
    // 오른쪽 하단 모서리
    canvas.drawLine(rect.bottomRight,
        rect.bottomRight - const Offset(cornerLength, 0), linePaint);
    canvas.drawLine(rect.bottomRight,
        rect.bottomRight - const Offset(0, cornerLength), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
