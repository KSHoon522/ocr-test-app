import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ocr_test_app/screens/ResultDetailScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({Key? key}) : super(key: key);

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List resultList = [];

  @override
  void initState() {
    super.initState();
    loadResults();
  }

  Future<void> loadResults() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? results = prefs.getStringList('ocrResults');
    if (results != null) {
      setState(() {
        resultList = results.map((result) => jsonDecode(result)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('결과 목록')),
      body: ListView.builder(
        itemCount: resultList.length,
        itemBuilder: (context, index) {
          Map<String, dynamic> result = resultList[index];
          return ListTile(
            title: Text(result['timestamp'] ?? '결과 ${index + 1}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResultDetailScreen(resultData: result),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
