import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../shared/widgets/button_progress.dart';
import '../../../shared/widgets/form_page.dart';
import '../../../shared/widgets/status_message.dart';
import 'credential_validators.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
          .login(email: _email.text.trim(), password: _password.text);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = describeFailure(e, context: FailureContext.login),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'imSafe · Lanzadores',
      children: [
        Text('Inicia sesión', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Contraseña'),
                validator: validatePassword,
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
              ? const ButtonProgress(label: 'Iniciando sesión…')
              : const Text('Iniciar sesión'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _submitting ? null : () => context.go(AppRoutes.register),
          child: const Text('Crear una cuenta'),
        ),
      ],
    );
  }
}
