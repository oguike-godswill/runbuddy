import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../../../core/network/api_endpoints.dart';
import '../state/auth_notifier.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password'),
          backgroundColor: AppColors.errorCoral,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await ref.read(authProvider.notifier).login(
          email: email,
          password: password,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        context.go(RouteNames.home);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Login failed'),
            backgroundColor: AppColors.errorCoral,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetIdController = TextEditingController(text: _emailController.text.trim());
    final newPassController = TextEditingController();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (modalCtx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.borderNavy, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.electricLime, size: 24),
              SizedBox(width: 10),
              Text(
                'Reset Password',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your registered email or username and choose a new password.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.midnightNavy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: TextField(
                  controller: resetIdController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary, size: 18),
                    labelText: 'Email or @Username',
                    labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.midnightNavy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: TextField(
                  controller: newPassController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: 18),
                    labelText: 'New Password (min 6 chars)',
                    labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isResetting
                  ? null
                  : () async {
                      final id = resetIdController.text.trim();
                      final pass = newPassController.text.trim();
                      if (id.isEmpty || pass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter identifier and password (min 6 chars)'),
                            backgroundColor: AppColors.errorCoral,
                          ),
                        );
                        return;
                      }

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(dialogCtx);

                      setDialogState(() => isResetting = true);
                      final res = await ref.read(authProvider.notifier).resetPassword(
                            identifier: id,
                            newPassword: pass,
                          );

                      if (dialogCtx.mounted) {
                        navigator.pop();
                      }
                      if (!mounted) return;

                      if (res['success'] == true) {
                        _emailController.text = id;
                        _passwordController.text = pass;
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'Password reset successfully!'),
                            backgroundColor: AppColors.electricLime,
                          ),
                        );
                      } else {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(res['error'] ?? 'Password reset failed'),
                            backgroundColor: AppColors.errorCoral,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricLime,
                foregroundColor: AppColors.midnightNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: isResetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.midnightNavy),
                    )
                  : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    final serverController = TextEditingController(text: ApiEndpoints.baseUrl);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderNavy, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: AppColors.electricLime, size: 22),
            SizedBox(width: 10),
            Text(
              'Server Connection',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set the host where Run Buddy server is running (Wi-Fi IP, ngrok tunnel, or cloud URL).',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.midnightNavy,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderNavy),
              ),
              child: TextField(
                controller: serverController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.link_rounded, color: AppColors.electricLime, size: 18),
                  labelText: 'Base URL',
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  backgroundColor: AppColors.midnightNavy,
                  side: const BorderSide(color: AppColors.borderNavy),
                  label: const Text('Wi-Fi (192.168.100.25)', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                  onPressed: () => serverController.text = 'http://192.168.100.25:4000',
                ),
                ActionChip(
                  backgroundColor: AppColors.midnightNavy,
                  side: const BorderSide(color: AppColors.borderNavy),
                  label: const Text('Localhost', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                  onPressed: () => serverController.text = 'http://127.0.0.1:4000',
                ),
                ActionChip(
                  backgroundColor: AppColors.midnightNavy,
                  side: const BorderSide(color: AppColors.borderNavy),
                  label: const Text('Emulator', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                  onPressed: () => serverController.text = 'http://10.0.2.2:4000',
                ),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = serverController.text.trim();
              if (newUrl.isNotEmpty) {
                await ApiEndpoints.setCustomBaseUrl(newUrl);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Server connected to: ${ApiEndpoints.baseUrl}'),
                      backgroundColor: AppColors.electricLime,
                    ),
                  );
                  setState(() {});
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricLime,
              foregroundColor: AppColors.midnightNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Save Host', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/running_duo.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.midnightNavy.withValues(alpha: 0.70),
                  AppColors.midnightNavy.withValues(alpha: 0.85),
                  AppColors.midnightNavy.withValues(alpha: 0.98),
                ],
                stops: const [0.0, 0.40, 0.80],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                        onPressed: () => context.canPop() ? context.pop() : context.go(RouteNames.onboarding),
                      ),
                      IconButton(
                        icon: const Icon(Icons.dns_rounded, color: AppColors.electricLime, size: 22),
                        tooltip: 'Server Connection',
                        onPressed: _showServerConfigDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.electricLime,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.electricLime.withValues(alpha: 0.45),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        size: 42,
                        color: AppColors.midnightNavy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'RUN BUDDY',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'NEVER RUN ALONE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: AppColors.electricLime,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceNavy.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderNavy, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'SIGN IN TO YOUR SESSION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          controller: _emailController,
                          label: 'Runner Email or @Username',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        // Password with visibility toggle
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.midnightNavy.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderNavy),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: AppColors.electricLime,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.electricLime,
                            foregroundColor: AppColors.midnightNavy,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: AppColors.electricLime.withValues(alpha: 0.4),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.midnightNavy,
                                  ),
                                )
                              : const Text(
                                  'SIGN IN & ENTER',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New runner? ',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => context.push(RouteNames.register),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            color: AppColors.electricLime,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderNavy),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
