import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class CreateJobForm extends ConsumerStatefulWidget {
  const CreateJobForm({super.key});

  @override
  ConsumerState<CreateJobForm> createState() => _CreateJobFormState();
}

class _CreateJobFormState extends ConsumerState<CreateJobForm> {
  final title = TextEditingController();
  final description = TextEditingController();
  final budget = TextEditingController();

  final picker = ImagePicker();
  final List<File> images = [];

  String? country;
  String? location;

  final countries = ["Ghana", "Nigeria", "Kenya"];

  final locations = {
    "Ghana": ["Accra", "Kumasi"],
    "Nigeria": ["Lagos", "Abuja"],
    "Kenya": ["Nairobi"],
  };

  Future<void> pickImages() async {
    final picked = await picker.pickMultiImage();

    for (final imgFile in picked) {
      final file = File(imgFile.path);

      final sizeMB = await file.length() / (1024 * 1024);

      if (sizeMB > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${imgFile.name} > 1MB skipped")),
        );
        continue;
      }

      if (images.length >= 3) break;

      images.add(file);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = JobsRepository();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: description, decoration: const InputDecoration(labelText: "Description")),
            TextField(controller: budget, decoration: const InputDecoration(labelText: "Budget")),

            DropdownButtonFormField(
              value: country,
              items: countries
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => country = v),
              decoration: const InputDecoration(labelText: "Country"),
            ),

            if (country != null)
              DropdownButtonFormField(
                value: location,
                items: locations[country]!
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => location = v),
                decoration: const InputDecoration(labelText: "Location"),
              ),

            ElevatedButton(
              onPressed: pickImages,
              child: const Text("Pick Images (max 3)"),
            ),

            Wrap(
              children: images
                  .map((e) => Image.file(e, width: 60, height: 60))
                  .toList(),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                await repo.createJob(
                  title: title.text,
                  description: description.text,
                  location: "$country - $location",
                  budget: double.tryParse(budget.text) ?? 0,
                  images: images,
                );

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Create Job"),
            ),
          ],
        ),
      ),
    );
  }
}