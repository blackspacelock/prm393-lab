import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class OllamaService {
  final Dio _dio = Dio();
  final String _apiUrl = 'http://localhost:11434/api/generate';

  Stream<String> generate(String prompt) {
    final controller = StreamController<String>();

    _dio.post(
      _apiUrl,
      data: {
        'model': 'qwen3.5:2b',// Or any other model you have
        'prompt': prompt,
        'stream': true,
      },
      options: Options(responseType: ResponseType.stream),
    ).then((response) {
      response.data.stream.listen(
        (data) {
          final decoded = utf8.decode(data);
          final lines = decoded.split('\n');
          for (final line in lines) {
            if (line.isNotEmpty) {
              try {
                final json = jsonDecode(line);
                if (json['response'] != null) {
                  controller.add(json['response']);
                }
                if (json['done'] == true) {
                  controller.close();
                }
              } catch (e) {
                // Ignore malformed JSON
              }
            }
          }
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
        onError: (error) {
          controller.addError(error);
          controller.close();
        },
      );
    }).catchError((error) {
      controller.addError(error);
      controller.close();
    });

    return controller.stream;
  }
}
