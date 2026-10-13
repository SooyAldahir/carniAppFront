import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Pantalla de arranque de instalacion: crea el primer Super
/// Administrador (RF-AUTH-005). Solo funciona si el sistema todavia no
/// tiene ningun usuario -- lo valida el backend, no esta pantalla.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCompletoController = TextEditingController();
  final _nombreUsuarioController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _nombreCompletoController.dispose();
    _nombreUsuarioController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);

    final auth = context.read<AuthProvider>();
    final exito = await auth.bootstrapAdmin(
      nombreCompleto: _nombreCompletoController.text.trim(),
      nombreUsuario: _nombreUsuarioController.text.trim(),
      correo: _correoController.text.trim().isEmpty ? null : _correoController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (exito) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (auth.ultimoError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.ultimoError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Super Administrador')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Esto solo funciona la primera vez, cuando el sistema '
                    'todavia no tiene ningun usuario creado.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nombreCompletoController,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nombreUsuarioController,
                    decoration: const InputDecoration(labelText: 'Usuario (para iniciar sesion)'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _correoController,
                    decoration: const InputDecoration(labelText: 'Correo (opcional)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'Minimo 8 caracteres' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmarController,
                    decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                    obscureText: true,
                    validator: (v) => (v != _passwordController.text)
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear y entrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
