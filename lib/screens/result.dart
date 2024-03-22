import 'package:flutter/material.dart';

class OCRResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const OCRResultScreen({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR 결과'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: result.length,
          itemBuilder: (context, index) {
            String key = result.keys.elementAt(index);
            dynamic value = result[key];
            return ListTile(
              title: Text(key),
              subtitle: Text(value.toString()),
            );
          },
        ),
      ),
    );
  }
}
