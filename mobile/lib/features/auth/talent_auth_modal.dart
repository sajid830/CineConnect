import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class TalentAuthModal extends StatefulWidget {
  final CineAppState appState;

  const TalentAuthModal({super.key, required this.appState});

  @override
  State<TalentAuthModal> createState() => _TalentAuthModalState();
}

class _TalentAuthModalState extends State<TalentAuthModal> {
  bool _isSignUp = false;
  int _signUpStep = 0; // 0: Guild & Identity, 1: 24-Crafts & Specialized Skills, 2: Gear, Rate & Verification

  // Form Controllers
  final _emailController = TextEditingController(text: 'mayaray@cinema.com');
  final _passwordController = TextEditingController(text: '••••••••');
  final _nameController = TextEditingController(text: 'Maya Ray');
  final _guildIdController = TextEditingController(text: 'ISC-9021');
  final _dayRateController = TextEditingController(text: '₹95,000 / Day');
  final _gearController = TextEditingController(text: 'ARRI Alexa 35, Cooke Anamorphic /i, Ronin 2');

  String _selectedPrimaryCraft = 'Cinematography / DOP';
  final Set<String> _chosenSkills = {
    'ARRI Alexa 35',
    'Cooke Anamorphic /i',
    'Unreal Engine 5 ICVFX',
    'DaVinci Resolve Studio',
  };

  final List<String> _availableSkillOptions = [
    'ARRI Alexa 35',
    'Cooke Anamorphic /i',
    'Unreal Engine 5 ICVFX',
    'DaVinci Resolve Studio',
    'Ronin 4D 8K',
    'SMPTE Timecode Sync',
    'Steadicam M-2',
    'Low-Key Film Noir Lighting',
    'Method Acting',
    'Martial Arts & Kalari',
    'Dolby Atmos 9.1.4 Mixing',
    'Avid Pro Tools HDX',
    'Drone FPV 6K',
    'Wire-Work Rigging',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _guildIdController.dispose();
    _dayRateController.dispose();
    _gearController.dispose();
    super.dispose();
  }

  void _finishAuth() {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CineColors.surfaceElevated,
        content: Row(
          children: [
            const Icon(Icons.verified, color: CineColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Welcome, ${_nameController.text}! Guild Verified (${_guildIdController.text}) on 24-Crafts Network.',
                style: const TextStyle(color: CineColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101116),
            border: Border.all(color: CineColors.gold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: CineColors.gold.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [CineColors.goldLight, CineColors.gold],
                            ),
                          ),
                          child: const Icon(Icons.movie_creation_rounded, size: 16, color: Colors.black),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSignUp ? '24-Crafts Talent Registration' : 'Talent Slate Gateway',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: CineColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: CineColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Subtitle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CineColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CineColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: CineColors.gold),
                      SizedBox(width: 6),
                      Text(
                        'Verified for Actors, Technicians, HODs & Crew',
                        style: TextStyle(fontSize: 11, color: CineColors.goldLight, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (!_isSignUp) ...[
                  // LOGIN FORM
                  const Text('Email or Guild ID (SICA / ISC / CINTAA)', style: TextStyle(fontSize: 12, color: CineColors.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined, size: 18, color: CineColors.gold),
                      hintText: 'e.g. ISC-9021 or email@cinema.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Access Passkey', style: TextStyle(fontSize: 12, color: CineColors.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline, size: 18, color: CineColors.gold),
                      hintText: '••••••••',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CineColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _finishAuth,
                      child: const Text('Enter Talent Digital Slate'),
                    ),
                  ),
                ] else ...[
                  // MULTI-STEP SIGN UP FLOW
                  Row(
                    children: [
                      _StepBadge(number: '1', title: 'Guild', isActive: _signUpStep == 0, isDone: _signUpStep > 0),
                      const Expanded(child: Divider(color: CineColors.border)),
                      _StepBadge(number: '2', title: 'Craft & Skills', isActive: _signUpStep == 1, isDone: _signUpStep > 1),
                      const Expanded(child: Divider(color: CineColors.border)),
                      _StepBadge(number: '3', title: 'Gear & Verify', isActive: _signUpStep == 2, isDone: false),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_signUpStep == 0) ...[
                    const Text('Full Name', style: TextStyle(fontSize: 12, color: CineColors.textMuted)),
                    const SizedBox(height: 4),
                    TextField(controller: _nameController),
                    const SizedBox(height: 10),
                    const Text('Official Union / Guild Registration ID',
                        style: TextStyle(fontSize: 12, color: CineColors.textMuted)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _guildIdController,
                      decoration: const InputDecoration(hintText: 'e.g. ISC-9021, SICA-4401, CINTAA-502'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => setState(() => _signUpStep = 1),
                        child: const Text('Proceed to 24-Crafts & Skills →'),
                      ),
                    ),
                  ] else if (_signUpStep == 1) ...[
                    const Text('Primary Cinema Craft (Select from 24 Crafts)', style: TextStyle(fontSize: 12, color: CineColors.textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: CineColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CineColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPrimaryCraft,
                          dropdownColor: CineColors.surfaceElevated,
                          isExpanded: true,
                          items: CinemaCraft.all24Crafts.map((craft) {
                            return DropdownMenuItem(
                              value: craft.name,
                              child: Text(craft.name, style: const TextStyle(fontSize: 13, color: CineColors.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPrimaryCraft = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Specialized Technical & Creative Skills:',
                        style: TextStyle(fontSize: 12, color: CineColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _availableSkillOptions.map((skill) {
                        final isSelected = _chosenSkills.contains(skill);
                        return FilterChip(
                          label: Text(
                            skill,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.black : CineColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: CineColors.gold,
                          backgroundColor: CineColors.surface,
                          checkmarkColor: Colors.black,
                          side: BorderSide(color: isSelected ? CineColors.gold : CineColors.border),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _chosenSkills.add(skill);
                              } else {
                                _chosenSkills.remove(skill);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() => _signUpStep = 0),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setState(() => _signUpStep = 2),
                            child: const Text('Next: Gear & Rate →'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text('Daily Call-Sheet Union Rate Bracket', style: TextStyle(fontSize: 12, color: CineColors.textMuted)),
                    const SizedBox(height: 4),
                    TextField(controller: _dayRateController),
                    const SizedBox(height: 10),
                    const Text('Owned / Operated Verified Gear', style: TextStyle(fontSize: 12, color: CineColors.textMuted)),
                    const SizedBox(height: 4),
                    TextField(controller: _gearController),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CineColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CineColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: CineColors.gold, size: 18),
                              SizedBox(width: 8),
                              Text('Cryptographic Ledger Verification',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Your credits, reel timecodes, and equipment will receive a cryptographic guild stamp enabling direct 1-tap call-sheet holds and instant hiring.',
                            style: TextStyle(fontSize: 11, color: CineColors.textMuted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() => _signUpStep = 1),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _finishAuth,
                            child: const Text('Create Talent Slate & Enter'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _signUpStep = 0;
                    }),
                    child: Text(
                      _isSignUp ? 'Already registered? Sign In' : 'New to CineConnect? Create 24-Crafts Slate',
                      style: const TextStyle(color: CineColors.gold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final String number;
  final String title;
  final bool isActive;
  final bool isDone;

  const _StepBadge({
    required this.number,
    required this.title,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isDone
              ? CineColors.gold
              : (isActive ? CineColors.goldLight : CineColors.surfaceElevated),
          child: Text(
            isDone ? '✓' : number,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDone || isActive ? Colors.black : CineColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? CineColors.gold : CineColors.textMuted,
          ),
        ),
      ],
    );
  }
}
