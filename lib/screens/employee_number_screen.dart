import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ingreso manual del número de empleado (prioridad 3 tras 1:N y QR).
class EmployeeNumberScreen extends StatefulWidget {
  const EmployeeNumberScreen({super.key});

  @override
  State<EmployeeNumberScreen> createState() => _EmployeeNumberScreenState();
}

class _EmployeeNumberScreenState extends State<EmployeeNumberScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final number = int.parse(_controller.text.trim());
    Navigator.of(context).pop(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Número de empleado')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Escriba el número de empleado',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Número',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) return 'Ingrese el número';
                    final n = int.tryParse(raw);
                    if (n == null || n <= 0) return 'Número inválido';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
