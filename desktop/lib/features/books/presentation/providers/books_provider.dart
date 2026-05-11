import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';

Dio _authDio() {
  const storage = FlutterSecureStorage();
  return Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
}

final adminBooksProvider = FutureProvider.family<
    Map<String, dynamic>,
    ({String searchTerm, String? genreId, DateTime? publishedFrom, DateTime? publishedTo})>(
  (ref, params) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {'Authorization': 'Bearer $token'},
    ));
    final queryParams = <String, dynamic>{
      if (params.searchTerm.isNotEmpty) 'searchTerm': params.searchTerm,
      if (params.genreId != null) 'genreId': params.genreId,
      if (params.publishedFrom != null)
        'publishedFrom': params.publishedFrom!.toIso8601String(),
      if (params.publishedTo != null)
        'publishedTo': params.publishedTo!.toIso8601String(),
    };
    final response = await dio.get('/api/books', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  },
);

final adminGenresProvider = FutureProvider<List<dynamic>>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  final response = await dio.get('/api/genres');
  return response.data as List<dynamic>;
});

Future<void> createBook({
  required String title,
  required String author,
  required String? description,
  required String? isbn,
  required bool isPublic,
  required List<String> genreIds,
}) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  await dio.post('/api/books', data: {
    'title': title,
    'author': author,
    'description': description,
    'isbn': isbn,
    'isPublic': isPublic,
    'genreIds': genreIds,
  });
}

Future<void> updateBook({
  required String id,
  required String title,
  required String author,
  required String? description,
  required String? isbn,
  required bool isPublic,
  required List<String> genreIds,
}) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  await dio.put('/api/books/$id', data: {
    'id': id,
    'title': title,
    'author': author,
    'description': description,
    'isbn': isbn,
    'isPublic': isPublic,
    'genreIds': genreIds,
  });
}

Future<void> deleteBook(String id) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));
  await dio.delete('/api/books/$id');
}

Future<void> uploadBookCover(String bookId) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final file = result.files.first;
  if (file.bytes == null) return;

  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));

  final formData = FormData.fromMap({
    'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
  });
  await dio.post('/api/books/$bookId/upload-cover', data: formData);
}

Future<void> uploadBookPdf(String bookId) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final file = result.files.first;
  if (file.bytes == null) return;

  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Authorization': 'Bearer $token'},
  ));

  final formData = FormData.fromMap({
    'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
  });
  await dio.post('/api/books/$bookId/upload-pdf', data: formData);
}
