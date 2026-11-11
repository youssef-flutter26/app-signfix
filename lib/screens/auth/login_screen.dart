import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'phone_otp_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    this.onBack,
  });
  final ApiClient api;
  final VoidCallback onAuthenticated;
  final VoidCallback? onBack; // back to portal selection
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _emailError;
  String? _passwordError;
  bool _showRegister = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final res = await AuthService.signInWithGoogle(role: 'customer');
      if (res == null) {
        // User cancelled account picker
        return;
      }
      final String? token = res['token']?.toString();
      if (token != null && token.isNotEmpty) {
        await widget.api.saveSession(
          token,
          email: res['user']?['email']?.toString(),
        );
        widget.onAuthenticated();
      } else {
        throw Exception('Token not received from server');
      }
    } catch (e) {
      if (mounted) {
        final str = e.toString().replaceFirst('Exception: ', '');
        setState(() => _error = str);
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final pass = _password.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
      _error = null;
    });

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _passwordError = 'Please enter your password.');
      return;
    }
    if (pass.length < 6) {
      setState(
          () => _passwordError = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.login(email, pass);
      widget.onAuthenticated();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          final msg = e.message.toLowerCase();
          if (e.field == 'email' ||
              e.code == 'EMAIL_NOT_FOUND' ||
              msg.contains('email') ||
              msg.contains('no account')) {
            _emailError = e.message;
          } else if (e.field == 'password' ||
              e.code == 'INVALID_PASSWORD' ||
              msg.contains('password')) {
            _passwordError = e.message;
          } else {
            _error = e.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final errLower = errStr.toLowerCase();
        setState(() {
          if (errLower.contains('email') || errLower.contains('no account')) {
            _emailError = errStr;
          } else if (errLower.contains('password')) {
            _passwordError = errStr;
          } else {
            _error = errStr;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _showRegister = false);
        },
        child: RegisterScreen(
          api: widget.api,
          onAuthenticated: widget.onAuthenticated,
          onLoginTap: () => setState(() => _showRegister = false),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          leading: widget.onBack != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppColors.gold),
                  onPressed: widget.onBack,
                )
              : null,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.jpeg',
                  width: 30, height: 30, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            RichText(
                text: const TextSpan(children: [
              TextSpan(
                  text: 'Sign',
                  style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              TextSpan(
                  text: 'Fix',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ])),
          ]),
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.gold.withValues(alpha: .3),
                                blurRadius: 20)
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/images/logo.jpeg',
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Customer Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.navy)),
                    const SizedBox(height: 6),
                    const Text(
                        'Order sign boards, request service\nand track every update.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textLight,
                            height: 1.4,
                            fontSize: 13)),
                    const SizedBox(height: 28),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppColors.charcoal),
                      decoration: InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: const Icon(Icons.mail_outline),
                        errorText: _emailError,
                      ),
                      onChanged: (_) {
                        if (_emailError != null || _error != null) {
                          setState(() {
                            _emailError = null;
                            _error = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(color: AppColors.charcoal),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.gold,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onChanged: (_) {
                        if (_passwordError != null || _error != null) {
                          setState(() {
                            _passwordError = null;
                            _error = null;
                          });
                        }
                      },
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: .4)),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13)),
                      ),
                    ],

                    const SizedBox(height: 20),
                    LoadingButton(
                        loading: _loading,
                        onPressed: _submit,
                        child: const Text('Sign In')),
                    const SizedBox(height: 14),
                    const Row(children: [
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ]),
                    const SizedBox(height: 14),
                    GoogleSignInButton(
                      loading: _googleLoading,
                      label: 'Continue with Google',
                      onPressed: _loading ? null : _handleGoogleSignIn,
                    ),

                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loading || _googleLoading
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PhoneOtpLoginScreen(
                                    authenticate: (idToken, name) =>
                                        widget.api.loginWithFirebasePhone(
                                      idToken: idToken,
                                      name: name,
                                    ),
                                    onAuthenticated: widget.onAuthenticated,
                                  ),
                                ),
                              ),
                      icon: const Icon(Icons.phone_android),
                      label: const Text('Continue with phone'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            customerApi: widget.api,
                            initialEmail: _email.text.trim(),
                            portalName: 'Customer',
                          ),
                        ),
                      ),
                      child: const Text('Forgot password?'),
                    ),

                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text("Don't have an account? ",
                          style: TextStyle(color: AppColors.textMuted)),
                      GestureDetector(
                        onTap: () => setState(() => _showRegister = true),
                        child: const Text('Register',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ), // Scaffold closes here (child of PopScope)
    ); // PopScope closes here
  } // build
} // _LoginScreenState
