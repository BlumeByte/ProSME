import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/job_model.dart';

class JobsRepository {
  final supabase = Supabase.instance.client;

  /// 🔥 COMPRESS IMAGE (AUTO < 1MB)
  Future<File> compressImage(File file) async {
    final bytes = await file.readAsBytes();

    final image = img.decodeImage(bytes);
    if (image == null) return file;

    int quality = 90;
    List<int> compressed = img.encodeJpg(image, quality: quality);

    while (compressed.length > 1024 * 1024 && quality > 10) {
      quality -= 10;
      compressed = img.encodeJpg(image, quality: quality);
    }

    final newFile = File(file.path)..writeAsBytesSync(compressed);

    return newFile;
  }

  /// 🚀 CREATE JOB
  Future<void> createJob({
    required String title,
    required String description,
    required String location,
    required double budget,
    required List<File> images,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) throw Exception("User not logged in");

    List<String> imageUrls = [];

    for (final file in images) {
      final compressed = await compressImage(file);

      final fileName =
          "${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg";

      await supabase.storage.from('job-images').upload(fileName, compressed);

      final url = supabase.storage.from('job-images').getPublicUrl(fileName);

      imageUrls.add(url);
    }

    await supabase.from('jobs').insert({
      'title': title,
      'description': description,
      'location': location,
      'budget': budget,
      'created_by': user.id,
      'status': 'open',
      'images': imageUrls,
    });
  }

  /// 🚀 STREAM JOBS
  Stream<List<Job>> watchJobs() {
    return supabase.from('jobs').stream(primaryKey: ['id']).map((data) {
      return data.map((row) {
        return Job(
          id: row['id'],
          title: row['title'] ?? '',
          description: row['description'] ?? '',
          location: row['location'] ?? '',
          budget: (row['budget'] ?? 0).toDouble(),
          createdBy: row['created_by'] ?? '',
          status: row['status'] ?? 'open',
          images: List<String>.from(row['images'] ?? []),
          createdAt:
              DateTime.tryParse(row['created_at'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    });
  }
}
