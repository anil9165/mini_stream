import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import 'auth_bloc.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isCreateAccount = false;
  bool _obscure = true;
  String _role = 'user';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF07100F),
                  Color(0xFF0E1718),
                  Color(0xFF181820),
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? 980 : 460,
                          minHeight: wide ? 620 : 0,
                        ),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(child: _AuthHeroPanel()),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _AuthFormPanel(
                                      isCreateAccount: _isCreateAccount,
                                      isLoading: isLoading,
                                      name: _name,
                                      email: _email,
                                      password: _password,
                                      obscure: _obscure,
                                      role: _role,
                                      onModeChanged: _setMode,
                                      onRoleChanged: (value) =>
                                          setState(() => _role = value),
                                      onTogglePassword: () =>
                                          setState(() => _obscure = !_obscure),
                                      onSubmit: _submit,
                                      onGoogle: () => context
                                          .read<AuthBloc>()
                                          .add(AuthGoogleRequested()),
                                      onGuest: () => context
                                          .read<AuthBloc>()
                                          .add(AuthGuestRequested()),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _CompactBrandHeader(),
                                  const SizedBox(height: 18),
                                  _AuthFormPanel(
                                    isCreateAccount: _isCreateAccount,
                                    isLoading: isLoading,
                                    name: _name,
                                    email: _email,
                                    password: _password,
                                    obscure: _obscure,
                                    role: _role,
                                    onModeChanged: _setMode,
                                    onRoleChanged: (value) =>
                                        setState(() => _role = value),
                                    onTogglePassword: () =>
                                        setState(() => _obscure = !_obscure),
                                    onSubmit: _submit,
                                    onGoogle: () => context
                                        .read<AuthBloc>()
                                        .add(AuthGoogleRequested()),
                                    onGuest: () => context.read<AuthBloc>().add(
                                      AuthGuestRequested(),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _setMode(bool createAccount) {
    setState(() {
      _isCreateAccount = createAccount;
      if (!createAccount) _role = 'user';
    });
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid email and at least 6 character password.',
          ),
        ),
      );
      return;
    }
    if (_isCreateAccount) {
      context.read<AuthBloc>().add(
        AuthCreateAccountRequested(_name.text.trim(), email, password, _role),
      );
      return;
    }
    context.read<AuthBloc>().add(AuthEmailRequested(email, password));
  }
}

class _AuthHeroPanel extends StatelessWidget {
  const _AuthHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF06312D), Color(0xFF122326), Color(0xFF241927)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AppMark(size: 58),
          const Spacer(),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Agora live studio for hosts. Clean live rooms for viewers.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 26),
          const _HeroSignalRow(),
        ],
      ),
    );
  }
}

class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _AppMark(size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Live streaming studio',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.isCreateAccount,
    required this.isLoading,
    required this.name,
    required this.email,
    required this.password,
    required this.obscure,
    required this.role,
    required this.onModeChanged,
    required this.onRoleChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onGoogle,
    required this.onGuest,
  });

  final bool isCreateAccount;
  final bool isLoading;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final String role;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCreateAccount ? 'Create account' : 'Welcome back',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              isCreateAccount
                  ? 'Choose user or admin access.'
                  : 'Login with email, Google, or guest access.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _ModeSwitch(
              isCreateAccount: isCreateAccount,
              onChanged: isLoading ? null : onModeChanged,
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isCreateAccount
                  ? Column(
                      key: const ValueKey('create-fields'),
                      children: [
                        TextField(
                          controller: name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RolePicker(
                          role: role,
                          onChanged: isLoading ? null : onRoleChanged,
                        ),
                        const SizedBox(height: 12),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('login-fields')),
            ),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: obscure,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isCreateAccount ? Icons.person_add_alt : Icons.login),
              label: Text(isCreateAccount ? 'Create Account' : 'Login'),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onGuest,
              icon: const Icon(Icons.person_outline),
              label: const Text('Guest'),
            ),
            // Row(
            //   children: [
            //     Expanded(
            //       child: OutlinedButton.icon(
            //         onPressed: isLoading ? null : onGoogle,
            //         icon: const Icon(Icons.g_mobiledata),
            //         label: const Text('Google'),
            //       ),
            //     ),
            //     const SizedBox(width: 10),
            //     Expanded(
            //       child: OutlinedButton.icon(
            //         onPressed: isLoading ? null : onGuest,
            //         icon: const Icon(Icons.person_outline),
            //         label: const Text('Guest'),
            //       ),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isCreateAccount, required this.onChanged});

  final bool isCreateAccount;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1417),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              selected: !isCreateAccount,
              icon: Icons.lock_open_outlined,
              label: 'Login',
              onTap: onChanged == null ? null : () => onChanged!(false),
            ),
          ),
          Expanded(
            child: _ModeButton(
              selected: isCreateAccount,
              icon: Icons.person_add_alt,
              label: 'Register',
              onTap: onChanged == null ? null : () => onChanged!(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF00D4A6) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFF031B17) : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF031B17) : Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.role, required this.onChanged});

  final String role;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleTile(
            selected: role == 'user',
            title: 'User',
            subtitle: 'Watch and join',
            icon: Icons.visibility_outlined,
            onTap: onChanged == null ? null : () => onChanged!('user'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoleTile(
            selected: role == 'admin',
            title: 'Admin',
            subtitle: 'Host and RTMP',
            icon: Icons.admin_panel_settings_outlined,
            onTap: onChanged == null ? null : () => onChanged!('admin'),
          ),
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFF0E302A)
          : Colors.white.withValues(alpha: .03),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00D4A6)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF00D4A6) : Colors.white70,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSignalRow extends StatelessWidget {
  const _HeroSignalRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _SignalChip(icon: Icons.wifi_tethering, label: 'Agora'),
        _SignalChip(icon: Icons.cloud_upload_outlined, label: 'RTMP'),
        _SignalChip(icon: Icons.chat_bubble_outline, label: 'Chat'),
      ],
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: .08),
      side: BorderSide(color: Colors.white.withValues(alpha: .1)),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF00D4A6).withValues(alpha: .14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00D4A6).withValues(alpha: .35),
        ),
      ),
      child: Icon(
        Icons.live_tv_outlined,
        color: const Color(0xFF00D4A6),
        size: size * .48,
      ),
    );
  }
}
