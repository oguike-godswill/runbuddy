import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../../auth/state/auth_notifier.dart';

Future<void> showEditProfileModal(BuildContext context, WidgetRef ref) {
  final user = ref.read(authProvider);
  if (user == null) return Future.value();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EditProfileSheet(user: user),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserSession user;
  const _EditProfileSheet({required this.user});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late int _selectedPaceSeconds;
  late double _selectedDistanceKm;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _paceOptions = const [
    {'label': '4\'30"/km', 'seconds': 270},
    {'label': '5\'00"/km', 'seconds': 300},
    {'label': '5\'30"/km', 'seconds': 330},
    {'label': '6\'00"/km', 'seconds': 360},
    {'label': '6\'30"/km', 'seconds': 390},
  ];

  final List<double> _distanceOptions = const [3.0, 5.0, 10.0, 15.0, 21.1];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _selectedPaceSeconds = widget.user.typicalPaceSeconds;
    _selectedDistanceKm = widget.user.typicalDistanceKm;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your runner name'),
          backgroundColor: AppColors.errorCoral,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final res = await ref.read(authProvider.notifier).updateProfile(
      displayName: name,
      typicalPaceSeconds: _selectedPaceSeconds,
      typicalDistanceKm: _selectedDistanceKm,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.freshGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Could not update profile'),
            backgroundColor: AppColors.errorCoral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.borderNavy, width: 1.5),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Runner Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Display Name
            const Text(
              'RUNNER DISPLAY NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSlateNavy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderNavy),
              ),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.electricLime),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: 'Your runner name',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Target Pace Selector
            const Text(
              'TARGET RUNNING PACE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paceOptions.map((opt) {
                final isSelected = _selectedPaceSeconds == opt['seconds'];
                return ChoiceChip(
                  label: Text(opt['label'] as String),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPaceSeconds = opt['seconds'] as int);
                    }
                  },
                  selectedColor: AppColors.electricLime,
                  backgroundColor: AppColors.surfaceSlateNavy,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.midnightNavy : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppColors.electricLime : AppColors.borderNavy,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 22),

            // Typical Distance Selector
            const Text(
              'TYPICAL WORKOUT DISTANCE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _distanceOptions.map((dist) {
                final isSelected = (_selectedDistanceKm - dist).abs() < 0.2;
                return ChoiceChip(
                  label: Text('${dist.toStringAsFixed(dist == 21.1 ? 1 : 0)} km'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDistanceKm = dist);
                    }
                  },
                  selectedColor: AppColors.buddyBlue,
                  backgroundColor: AppColors.surfaceSlateNavy,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppColors.buddyBlue : AppColors.borderNavy,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricLime,
                foregroundColor: AppColors.midnightNavy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.midnightNavy,
                      ),
                    )
                  : const Text(
                      'SAVE CHANGES',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
