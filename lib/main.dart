import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ocr_test_app/screens/ResultList.dart';
import 'package:ocr_test_app/screens/result.dart';

List<CameraDescription> cameras = [];

void main() async {
  await dotenv.load(fileName: 'asset/config/.env');
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ImageAnalysisPage(),
    );
  }
}

class ImageAnalysisPage extends StatefulWidget {
  const ImageAnalysisPage({super.key});

  @override
  _ImageAnalysisPageState createState() => _ImageAnalysisPageState();
}

class _ImageAnalysisPageState extends State<ImageAnalysisPage> {
  final ocrapiKey = dotenv.env['OCR_API_Key'];
  final openAIapiKey = dotenv.env['OpenAIapiKey'];
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  String _AnalyzingState = '';

  Future<void> _pickAndAnalyzeImage() async {
    setState(() {
      _isAnalyzing = true; // 분석 시작
    });
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      setState(() {
        _AnalyzingState = 'OCR 처리중';
      });
      // OCR 처리
      final ocrText = await sendImageToAPI(image);
      setState(() {
        _AnalyzingState = 'GPT-4-Vision-Preview 모델 분석중';
      });
      // GPT-4-Vision-Preview 모델 분석 요청
      await _analyzeImageWithGPT4(ocrText, base64Image);
    }
    setState(() {
      _isAnalyzing = false; // 분석 완료
    });
  }

  Future<String?> sendImageToAPI(XFile imagePath) async {
    var uri = Uri.parse('https://api.upstage.ai/v1/document-ai/ocr');
    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $ocrapiKey'
      ..files
          .add(await http.MultipartFile.fromPath('document', imagePath.path));

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseData = await response.stream.toBytes();
      var responseString = utf8.decode(responseData);
      var jsonResponse = jsonDecode(responseString);
      return jsonResponse['text'];
    } else {
      print('OCR 처리 실패');
    }
    return null;
  }

  Future<void> _analyzeImageWithGPT4(
      String? ocrText, String base64Image) async {
    const String apiUrl = 'https://api.openai.com/v1/chat/completions';

    const prompt =
        "다음은 이 사진의 텍스트야. 이미지의 왼쪽과 오른쪽을 구분해서 카테고리와 메뉴명 그리고 가격을 표로 보여주고, json 으로 정리해줘. 이미지에서 간격이 넓은건 별도 카테고리고, 가까이 있으면서 카테고리 구분없이 세로로 정렬된건 동일한 카테고리 내용이야";

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $openAIapiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4-vision-preview',
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": "$prompt, $ocrText"},
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
              }
            ]
          }
        ],
        "max_tokens": 1500
      }),
    );

    if (response.statusCode == 200) {
      final String decodedBody = utf8.decode(response.bodyBytes);
      final responseData = jsonDecode(decodedBody);
      if (!mounted) return;
      saveResult(responseData);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OCRResultScreen(result: responseData),
        ),
      );
    } else {
      return print('$response.statusCode: $response.reasonPhrase');
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

  Future<void> takePicture() async {
    setState(() {
      _isAnalyzing = true; // 분석 시작
    });
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      setState(() {
        _AnalyzingState = 'OCR 처리중';
      });
      // OCR 처리
      final ocrText = await sendImageToAPI(image);
      setState(() {
        _AnalyzingState = 'GPT-4-Vision-Preview 모델 분석중';
      });
      // GPT-4-Vision-Preview 모델 분석 요청
      await _analyzeImageWithGPT4(ocrText, base64Image);
    }
    setState(() {
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Test & Gpt-4-Vision'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isAnalyzing
                ? Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_AnalyzingState),
                    ],
                  )
                : ElevatedButton(
                    onPressed: _pickAndAnalyzeImage,
                    child: const Text('이미지 선택'),
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: takePicture,
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
/* 
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ocrapiKey = dotenv.env['OCR_API_Key'];
  final openAIapiKey = dotenv.env['OpenAIapiKey'];
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

  Future<void> takePicture() async {
    if (!controller!.value.isInitialized) {
      print("Controller is not initialized");
      return;
    }

    // 사진 찍기
    final image = await controller!.takePicture();

    // 이미지 파일을 불러옴
    final originalImageBytes = File(image.path).readAsBytesSync();
    final originalImage = img.decodeImage(originalImageBytes);

    if (originalImage != null) {
      // 가이드에 맞춰 이미지를 자름
      // 예시에서는 이미지의 중앙 80%를 자르는 것으로 가정
      final startX = (originalImage.width * 0.1).round();
      final startY = (originalImage.height * 0.1).round();
      final width = (originalImage.width * 0.8).round();
      final height = (originalImage.height * 0.8).round();

      final croppedImage = img.copyCrop(originalImage,
          x: startX, y: startY, width: width, height: height);

      final bytes = img.encodePng(croppedImage);
      final base64Image = base64Encode(bytes);

      // 잘린 이미지를 새 파일에 저장
      final croppedFilePath =
          '${(await getTemporaryDirectory()).path}/cropped.png';
      File(croppedFilePath).writeAsBytesSync(bytes);
      final XFile xCroppedFile = XFile(croppedFilePath);
      // 잘린 이미지를 API에 보냄
      final ocrText = await sendImageToAPI(xCroppedFile);

      await _analyzeImageWithGPT4(ocrText, base64Image);
    }
  }

  Future<String?> sendImageToAPI(XFile imagePath) async {
    var uri = Uri.parse('https://api.upstage.ai/v1/document-ai/ocr');
    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $ocrapiKey'
      ..files
          .add(await http.MultipartFile.fromPath('document', imagePath.path));

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseData = await response.stream.toBytes();
      var responseString = utf8.decode(responseData);
      var jsonResponse = jsonDecode(responseString);
      return jsonResponse['text'];
    } else {
      print('OCR 처리 실패');
    }
    return null;
  }

  Future<void> _analyzeImageWithGPT4(
      String? ocrText, String base64Image) async {
    const String apiUrl = 'https://api.openai.com/v1/chat/completions';

    const prompt =
        "다음은 이 사진의 텍스트야. 이미지의 왼쪽과 오른쪽을 구분해서 카테고리와 메뉴명 그리고 가격을 표로 보여주고, json 으로 정리해줘. 이미지에서 간격이 넓은건 별도 카테고리고, 가까이 있으면서 카테고리 구분없이 세로로 정렬된건 동일한 카테고리 내용이야";

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $openAIapiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4-vision-preview',
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": "$prompt, $ocrText"},
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
              }
            ]
          }
        ],
        "max_tokens": 1500
      }),
    );

    if (response.statusCode == 200) {
      final String decodedBody = utf8.decode(response.bodyBytes);
      final responseData = jsonDecode(decodedBody);
      if (!mounted) return;
      saveResult(responseData);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OCRResultScreen(result: responseData),
        ),
      );
    } else {
      return print(response.reasonPhrase);
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
                  final double appBarHeight =
                      kToolbarHeight + MediaQuery.of(context).padding.top;
                  final double availableHeight =
                      constraints.maxHeight - appBarHeight - 20;
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
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await takePicture();
                  },
                  child: const Icon(Icons.camera),
                ),
              ],
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
 */
