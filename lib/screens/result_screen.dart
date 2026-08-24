import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.success,
    required this.title,
    this.subtitle,
    this.attendanceType,
  });

  final bool success;
  final String title;
  final String? subtitle;
  final AttendanceType? attendanceType;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success ? Colors.green.shade700 : Colors.red.shade700;
    final icon = widget.success ? Icons.check_circle : Icons.cancel;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 120, color: color),
              const SizedBox(height: 24),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (widget.attendanceType != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.attendanceType!.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
              ],
              const SizedBox(height: 48),
              Text(
                'Regresando al inicio…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
