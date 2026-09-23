import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:horas_hombre_mobile/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminPinGuard {
  AdminPinGuard._();

  static const _attemptsKey = 'admin_pin_failed_attempts';
  static const _lockedUntilKey = 'admin_pin_locked_until';
  static const _maxAttempts = 5;
  static const _lockDuration = Duration(minutes: 5);

  static Future<bool> requestAccess(BuildContext context) async {
    if (!AppConfig.hasValidKioskAdminPin) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PIN administrativo no configurado'),
          content: const Text(
            'Compile la app indicando KIOSK_ADMIN_PIN con un PIN de 6 dígitos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lockedUntilMilliseconds = prefs.getInt(_lockedUntilKey);
    final lockedUntil = lockedUntilMilliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockedUntilMilliseconds);

    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
      if (!context.mounted) return false;
      await _showLockedDialog(context, lockedUntil);
      return false;
    }

    if (lockedUntil != null) {
      await _clearFailures(prefs);
    }

    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _AdminPinDialog(prefs: prefs),
        ) ??
        false;
  }

  static Future<void> _showLockedDialog(
    BuildContext context,
    DateTime lockedUntil,
  ) {
    final remaining = lockedUntil.difference(DateTime.now());
    final minutes = (remaining.inSeconds / 60).ceil();
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acceso bloqueado'),
        content: Text(
          'Se excedió el número de intentos. Intente nuevamente en '
          '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static Future<void> _clearFailures(SharedPreferences prefs) async {
    await prefs.remove(_attemptsKey);
    await prefs.remove(_lockedUntilKey);
  }
}

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog({required this.prefs});

  final SharedPreferences prefs;

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;
  bool _locked = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_checking) return;
    if (_controller.text.length != 6) {
      setState(() => _error = 'Ingrese los 6 dígitos.');
      return;
    }

    setState(() => _checking = true);

    if (_controller.text == AppConfig.kioskAdminPin) {
      await AdminPinGuard._clearFailures(widget.prefs);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final attempts = (widget.prefs.getInt(AdminPinGuard._attemptsKey) ?? 0) + 1;
    await widget.prefs.setInt(AdminPinGuard._attemptsKey, attempts);

    if (attempts >= AdminPinGuard._maxAttempts) {
      final lockedUntil = DateTime.now().add(AdminPinGuard._lockDuration);
      await widget.prefs.setInt(
        AdminPinGuard._lockedUntilKey,
        lockedUntil.millisecondsSinceEpoch,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _checking = false;
        _locked = true;
        _error = 'Acceso bloqueado durante 5 minutos.';
      });
      return;
    }

    if (!mounted) return;
    _controller.clear();
    setState(() {
      _checking = false;
      _error =
          'PIN incorrecto. Quedan ${AdminPinGuard._maxAttempts - attempts} intentos.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_checking,
      child: AlertDialog(
        title: const Text('Acceso administrativo'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'PIN de 6 dígitos',
            errorText: _error,
            counterText: '',
          ),
          onSubmitted: (_) => _verify(),
        ),
        actions: [
          TextButton(
            onPressed: _checking
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _checking || _locked ? null : _verify,
            child: _checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Desbloquear'),
          ),
        ],
      ),
    );
  }
}
