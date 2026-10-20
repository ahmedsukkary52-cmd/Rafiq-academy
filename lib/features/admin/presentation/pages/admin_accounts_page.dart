import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';
import '../bloc/admin_operations_bloc.dart';
import '../widgets/admin_operation_widgets.dart';

/// C1 / WA-1 — Admin provisions accounts via `adminProvisionUser` (P0-02).
class AdminAccountsPage extends StatelessWidget {
  const AdminAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminOperationsScaffold(
      title: 'إنشاء حساب',
      builder: (context, state) => const _ProvisionForm(),
    );
  }
}

class _ProvisionForm extends StatefulWidget {
  const _ProvisionForm();

  @override
  State<_ProvisionForm> createState() => _ProvisionFormState();
}

class _ProvisionFormState extends State<_ProvisionForm> {
  static const _roles = <String, String>{
    AppRoles.student: 'طالب',
    AppRoles.parent: 'ولي أمر',
    AppRoles.teacher: 'معلم',
    AppRoles.supervisor: 'مشرف',
  };

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = AppRoles.student;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AdminOperationsBloc>().add(
      ProvisionAccountEvent(
        ProvisionUserParams(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
          role: _role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        children: [
          AdminSectionCard(
            title: 'بيانات الحساب',
            subtitle: 'يُنشأ الحساب على الخادم مع ملف الدور المناسب',
            children: [
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'الدور'),
                items: [
                  for (final e in _roles.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'أدخل الاسم' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
                validator: (v) => (v ?? '').contains('@')
                    ? null
                    : 'أدخل بريداً إلكترونياً صحيحاً',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور المبدئية',
                ),
                validator: (v) => (v ?? '').length < 6
                    ? 'كلمة المرور 6 أحرف على الأقل'
                    : null,
              ),
              const SizedBox(height: 16),
              AdminSubmitButton(label: 'إنشاء الحساب', onPressed: _submit),
            ],
          ),
        ],
      ),
    );
  }
}
