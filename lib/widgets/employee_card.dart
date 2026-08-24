import 'dart:typed_data';

import 'package:flutter/material.dart';

class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.fullName,
    this.departmentName,
    this.photograph,
  });

  final String fullName;
  final String? departmentName;
  final Uint8List? photograph;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: photograph != null && photograph!.isNotEmpty
                  ? MemoryImage(photograph!)
                  : null,
              child: photograph == null || photograph!.isEmpty
                  ? Icon(Icons.person, size: 40, color: Colors.grey.shade600)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (departmentName != null && departmentName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      departmentName!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
