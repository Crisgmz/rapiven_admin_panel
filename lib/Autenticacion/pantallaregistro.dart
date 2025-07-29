import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusinessRegisterScreen extends StatefulWidget {
  const BusinessRegisterScreen({super.key});

  @override
  State<BusinessRegisterScreen> createState() => _BusinessRegisterScreenState();
}

class _BusinessRegisterScreenState extends State<BusinessRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String selectedBusinessType = 'restaurante';
  bool isLoading = false;

  // Lista simplificada de tipos de negocio
  final List<Map<String, String>> businessTypes = [
    {'value': 'restaurante', 'label': 'Restaurante'},
    {'value': 'cafeteria', 'label': 'Cafetería'},
    {'value': 'bar', 'label': 'Bar'},
    {'value': 'food_truck', 'label': 'Food Truck'},
    {'value': 'heladeria', 'label': 'Heladería'},
    {'value': 'dark_kitchen', 'label': 'Dark Kitchen'},
    {'value': 'pizzeria', 'label': 'Pizzería'},
    {'value': 'panaderia', 'label': 'Panadería y Repostería'},
    {'value': 'comedor', 'label': 'Comedor'},
    {'value': 'buffet', 'label': 'Buffet'},
  ];

  Future<void> registerBusiness() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // Crear usuario en Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final uid = credential.user!.uid;

      // Guardar en la colección unificada 'negocios'
      await FirebaseFirestore.instance.collection('negocios').doc(uid).set({
        'nombre': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'direccion': _addressController.text.trim(),
        'tipo': selectedBusinessType,
        'owner_uid': uid,
        'activo': true,
        'verificado': false,
        'rating': 0.0,
        'total_reviews': 0,
        'servicios': <String>[],
        'tags': [selectedBusinessType],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Opcional: Crear perfil de usuario
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'email': _emailController.text.trim(),
        'tipo_cuenta': 'negocio',
        'negocio_id': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Negocio registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al crear la cuenta';

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'La contraseña debe tener al menos 6 caracteres';
          break;
        case 'email-already-in-use':
          errorMessage = 'Este email ya está registrado';
          break;
        case 'invalid-email':
          errorMessage = 'Email inválido';
          break;
        default:
          errorMessage = 'Error: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Negocio'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Tipo de negocio
              DropdownButtonFormField<String>(
                value: selectedBusinessType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de negocio',
                  border: OutlineInputBorder(),
                ),
                items: businessTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type['value'],
                        child: Text(type['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => selectedBusinessType = value!),
              ),
              const SizedBox(height: 16),

              // Nombre del negocio
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.trim().length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El email es requerido';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value.trim())) {
                    return 'Ingrese un email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Contraseña
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La contraseña es requerida';
                  }
                  if (value.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Teléfono
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El teléfono es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dirección
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La dirección es requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Botón de registro
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : registerBusiness,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Registrando...'),
                          ],
                        )
                      : const Text(
                          'Registrar Negocio',
                          style: TextStyle(fontSize: 16),
                        ),
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
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
