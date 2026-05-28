import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider temporaneo per passare i dati di condivisione tra pagine
final dataShareDataProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final dataSharePinProvider = StateProvider<String?>((ref) => null);
