import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/applications_providers.dart';

class ApplyToJobSheet extends ConsumerStatefulWidget {
  const ApplyToJobSheet({
    super.key,
    required this.jobId,
  });

  final String jobId;

  @override
  ConsumerState<ApplyToJobSheet> createState() => _ApplyToJobSheetState();
}

class _ApplyToJobSheetState extends ConsumerState<ApplyToJobSheet> {
  final messageController = TextEditingController();
  final priceController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool isLoading = false;

  Future<void> submitApplication() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      await ref.read(applicationsRepositoryProvider).applyToJob(
            jobId: widget.jobId,
            message: messageController.text.trim(),
            proposedPrice: double.tryParse(priceController.text.trim()) ?? 0,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Application failed: $e')),
        );
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Apply to Job',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: messageController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Explain why you are the right artisan',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Message is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Proposed price',
                  prefixText: 'GHS ',
                ),
                validator: (value) {
                  final price = double.tryParse(value ?? '');
                  if (price == null || price <= 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : submitApplication,
                  child: Text(isLoading ? 'Submitting...' : 'Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    priceController.dispose();
    super.dispose();
  }
}
