import 'package:flutter/material.dart';

class ResultDetailScreen extends StatelessWidget {
  final Map<String, dynamic> resultData;

  const ResultDetailScreen({Key? key, required this.resultData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(resultData['timestamp'] ?? '결과 상세'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: resultData.length,
          itemBuilder: (context, index) {
            String key = resultData.keys.elementAt(index);
            dynamic value = resultData[key];
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
