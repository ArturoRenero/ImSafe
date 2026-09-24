import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../shared/widgets/button_progress.dart';
import '../../../shared/widgets/form_page.dart';
import '../../../shared/widgets/status_message.dart';
import '../data/auth_dtos.dart';
import 'credential_validators.dart';
import 'session_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = describeFailure(e, context: FailureContext.register),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Crear cuenta',
      children: [
        const StatusMessage(
          tone: StatusTone.info,
          message:
              'La cuenta no otorga permisos. Después deberás solicitar acceso '
              'a una institución y esperar su aprobación.',
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_submitting,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_submitting,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  helperText:
                      'Mínimo ${CredentialRules.passwordMinLength} caracteres; '
                      'puede ser una frase.',
                ),
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmation,
                enabled: !_submitting,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                ),
                validator: (value) => value == _password.text
                    ? null
                    : 'Las contraseñas no coinciden.',
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_error case final error?) ...[
          StatusMessage(message: error, tone: StatusTone.error),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const ButtonProgress(label: 'Creando cuenta…')
              : const Text('Crear cuenta'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _submitting ? null : () => context.go(AppRoutes.login),
          child: const Text('Ya tengo cuenta'),
        ),
      ],
    );
  }
}
