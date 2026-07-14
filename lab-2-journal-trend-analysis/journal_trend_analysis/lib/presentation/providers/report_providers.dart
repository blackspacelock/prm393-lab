import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/report_service.dart';

final reportServiceProvider = Provider(
  (_) => ReportService(FirebaseStorage.instance),
);
