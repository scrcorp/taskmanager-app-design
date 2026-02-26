import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/toast_manager.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _currentStep = 0;

  // Step 1: Terms
  bool _term1 = false;
  bool _term2 = false;
  bool _term3 = false;

  // Step 2: Email verification
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _emailVerified = false;

  // Step 3: Info
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _idChecked = false;
  bool _pwConfirmed = false;
  final List<String> _selectedWorkplaces = [];
  String? _selectedLanguage;

  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    setState(() => _currentStep++);
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    setState(() => _currentStep--);
  }

  // Step 1 validation
  void _validateStep1() {
    if (!_term1 || !_term2 || !_term3) {
      ToastManager().warning(context, '모든 약관에 동의해주세요.');
      return;
    }
    _nextStep();
  }

  // Step 2 mock actions
  Future<void> _sendCode() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ToastManager().warning(context, '이메일을 입력해주세요.');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
      ToastManager().success(context, '인증번호가 발송되었습니다.');
    }
  }

  Future<void> _verifyCode() async {
    if (_codeCtrl.text.trim().isEmpty) {
      ToastManager().warning(context, '인증번호를 입력해주세요.');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _emailVerified = true;
        _isLoading = false;
      });
      ToastManager().success(context, '인증이 완료되었습니다.');
    }
  }

  void _validateStep2() {
    if (!_emailVerified) {
      ToastManager().warning(context, '이메일 인증을 완료해주세요.');
      return;
    }
    _nextStep();
  }

  // Step 3 mock actions
  Future<void> _checkId() async {
    if (_idCtrl.text.trim().isEmpty) {
      ToastManager().warning(context, 'ID를 입력해주세요.');
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _idChecked = true;
        _isLoading = false;
      });
      ToastManager().success(context, '사용 가능한 ID입니다.');
    }
  }

  void _confirmPassword() {
    if (_confirmPwCtrl.text != _pwCtrl.text) {
      ToastManager().warning(context, '비밀번호가 일치하지 않습니다.');
      return;
    }
    if (_confirmPwCtrl.text.isEmpty) {
      ToastManager().warning(context, '비밀번호를 입력해주세요.');
      return;
    }
    setState(() => _pwConfirmed = true);
    ToastManager().success(context, '비밀번호가 확인되었습니다.');
  }

  void _validateStep3() {
    if (_nameCtrl.text.trim().isEmpty) {
      ToastManager().warning(context, '이름을 입력해주세요.');
      return;
    }
    if (!_idChecked) {
      ToastManager().warning(context, 'ID 중복 확인을 해주세요.');
      return;
    }
    if (_pwCtrl.text.length < 6) {
      ToastManager().warning(context, '비밀번호는 6자 이상이어야 합니다.');
      return;
    }
    if (!_pwConfirmed) {
      ToastManager().warning(context, '비밀번호 확인을 해주세요.');
      return;
    }
    if (_selectedWorkplaces.isEmpty) {
      ToastManager().warning(context, '근무지를 선택해주세요.');
      return;
    }
    if (_selectedLanguage == null) {
      ToastManager().warning(context, '언어를 선택해주세요.');
      return;
    }
    _nextStep();
  }

  // Step 4: actual register call
  Future<void> _completeRegistration() async {
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).register(
      username: _idCtrl.text.trim(),
      password: _pwCtrl.text,
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.go('/home');
      } else {
        final error = ref.read(authProvider).error ?? '회원가입에 실패했습니다.';
        ToastManager().error(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top bar ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  if (_currentStep < 3)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: _currentStep == 0
                          ? () => context.go('/login')
                          : _prevStep,
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  if (_currentStep < 3)
                    Text(
                      '회원가입',
                      style: Theme.of(context).textTheme.headlineMedium,
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  if (_currentStep == 3)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: _completeRegistration,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // ─── Progress bar ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _StepProgressBar(
                currentStep: _currentStep,
                totalSteps: 4,
              ),
            ),

            // ─── Content ──────────────────────────
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Step Builders
  // ═══════════════════════════════════════════════════════════════

  // ─── Step 1: 약관 동의 ────────────────────────────

  Widget _buildStep1() {
    final allAgreed = _term1 && _term2 && _term3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '약관을 확인해주세요',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '서비스 이용을 위해 약관에 동의해주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          // Terms content placeholder
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '계정 관련 약관 약관\n\n'
                      '본 약관은 서비스 이용에 관한 기본적인 사항을 규정합니다. '
                      '서비스를 이용하시기 전에 약관 내용을 반드시 확인해주세요.\n\n'
                      '제1조 (목적)\n본 약관은 회사가 제공하는 서비스의 이용과 관련하여 '
                      '회사와 회원 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n'
                      '제2조 (정의)\n본 약관에서 사용하는 용어의 정의는 다음과 같습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // All agree
                  _TermCheckbox(
                    label: '약관 전체동의',
                    value: allAgreed,
                    isBold: true,
                    onChanged: (_) {
                      final newVal = !allAgreed;
                      setState(() {
                        _term1 = newVal;
                        _term2 = newVal;
                        _term3 = newVal;
                      });
                    },
                  ),
                  const Divider(height: 24),
                  _TermCheckbox(
                    label: '계정 관련 약관에 동의합니다. (필수)',
                    value: _term1,
                    onChanged: (v) => setState(() => _term1 = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  _TermCheckbox(
                    label: '개인정보 수집 및 이용에 동의합니다. (필수)',
                    value: _term2,
                    onChanged: (v) => setState(() => _term2 = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  _TermCheckbox(
                    label: '마케팅 정보 수신에 동의합니다. (선택)',
                    value: _term3,
                    onChanged: (v) => setState(() => _term3 = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _BottomButton(
            label: '다음',
            onPressed: allAgreed ? _validateStep1 : null,
          ),
        ],
      ),
    );
  }

  // ─── Step 2: 이메일 본인 인증 ──────────────────────

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '본인 인증',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '이메일을 통해 본인 인증을 진행해주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          // Email field
          const _FormLabel('이메일'),
          const SizedBox(height: 8),
          _FieldWithButton(
            controller: _emailCtrl,
            hint: 'example@email.com',
            buttonLabel: _codeSent ? '재발송' : '인증번호 보내기',
            onButtonTap: _emailVerified ? null : _sendCode,
            keyboardType: TextInputType.emailAddress,
            isDone: _emailVerified,
          ),
          const SizedBox(height: 20),
          // Verification code
          const _FormLabel('인증번호'),
          const SizedBox(height: 8),
          _FieldWithButton(
            controller: _codeCtrl,
            hint: '인증번호 6자리',
            buttonLabel: '인증',
            onButtonTap: _codeSent && !_emailVerified ? _verifyCode : null,
            isDone: _emailVerified,
          ),
          const Spacer(),
          _BottomButton(
            label: '본인인증',
            onPressed: _emailVerified ? _validateStep2 : null,
          ),
        ],
      ),
    );
  }

  // ─── Step 3: 정보 입력 ────────────────────────────

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '간단한 정보를 알려주세요.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '서비스 이용에 필요한 기본 정보를 입력해주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormLabel('이름'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(hintText: '이름을 입력해주세요.'),
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('아이디'),
                  const SizedBox(height: 8),
                  _FieldWithButton(
                    controller: _idCtrl,
                    hint: '아이디를 입력해주세요.',
                    buttonLabel: '중복 확인',
                    onButtonTap: _idChecked ? null : _checkId,
                    isDone: _idChecked,
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('비밀번호'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '6자리 이상 입력해주세요.'),
                  ),
                  const SizedBox(height: 20),
                  const _FormLabel('비밀번호 확인'),
                  const SizedBox(height: 8),
                  _FieldWithButton(
                    controller: _confirmPwCtrl,
                    hint: '비밀번호를 다시 입력해주세요.',
                    buttonLabel: '확인',
                    onButtonTap: _pwConfirmed ? null : _confirmPassword,
                    obscureText: true,
                    isDone: _pwConfirmed,
                  ),
                  const SizedBox(height: 28),
                  const Divider(height: 1),
                  const SizedBox(height: 28),
                  // Workplace checkboxes
                  const _FormLabel('근무지 (중복선택 가능)'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['본사', '강남점', '홍대점', '부산점', '제주점']
                        .map((place) => _ChipCheckbox(
                              label: place,
                              selected: _selectedWorkplaces.contains(place),
                              onTap: () {
                                setState(() {
                                  if (_selectedWorkplaces.contains(place)) {
                                    _selectedWorkplaces.remove(place);
                                  } else {
                                    _selectedWorkplaces.add(place);
                                  }
                                });
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  // Language select
                  const _FormLabel('언어'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLanguage,
                    hint: const Text('언어를 선택해주세요.'),
                    decoration: const InputDecoration(),
                    items: ['한국어', 'English', 'Español']
                        .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLanguage = v),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BottomButton(
            label: '다음',
            onPressed: _validateStep3,
          ),
        ],
      ),
    );
  }

  // ─── Step 4: 가입 완료 ────────────────────────────

  Widget _buildStep4() {
    final name = _nameCtrl.text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Greeting
          Text(
            '$name님,',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '회원가입을 축하합니다!',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 40),
          // Illustration area
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(80),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.waving_hand_rounded,
                  size: 72,
                  color: AppColors.accent,
                ),
                // Decorative dots
                Positioned(
                  top: 20,
                  right: 24,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 28,
                  left: 20,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '지금 바로 서비스를 이용해보세요.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          _BottomButton(
            label: '시작하기',
            onPressed: _isLoading ? null : _completeRegistration,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Private sub-widgets
// ═══════════════════════════════════════════════════════════════

// ─── Step Progress Bar ─────────────────────────────

class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepProgressBar({
    required this.currentStep,
    required this.totalSteps,
  });

  static const _labels = ['약관동의', '본인인증', '정보 입력', '가입 완료'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress bar track
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: (currentStep + 1) / totalSteps,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalSteps, (i) {
            final isActive = i <= currentStep;
            return Text(
              _labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: i == currentStep ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.accent : AppColors.textMuted,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Form Label ────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    );
  }
}

// ─── Term Checkbox ─────────────────────────────────

class _TermCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool isBold;

  const _TermCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppColors.accent : AppColors.border,
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 15 : 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip Checkbox (for workplace) ─────────────────

class _ChipCheckbox extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipCheckbox({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Field with inline button ──────────────────────

class _FieldWithButton extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String buttonLabel;
  final VoidCallback? onButtonTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool isDone;

  const _FieldWithButton({
    required this.controller,
    required this.hint,
    required this.buttonLabel,
    this.onButtonTap,
    this.obscureText = false,
    this.keyboardType,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: onButtonTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDone ? AppColors.success : AppColors.accentBg,
              foregroundColor: isDone ? AppColors.white : AppColors.accent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, size: 18)
                : Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom CTA Button ─────────────────────────────

class _BottomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _BottomButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}
