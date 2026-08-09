import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../application/time_slots_provider.dart';
import '../../data/models/time_slot_model.dart';

/// Args passed via go_router's `extra` to /owner/slots/form — [slot]
/// null means "add mode", non-null means "edit mode" (capacity only,
/// see bookings_repository.dart's updateTimeSlotCapacity doc comment
/// for why slot_time isn't editable after creation). Same pattern as
/// MenuItemFormArgs in menu_item_form_screen.dart.
class TimeSlotFormArgs {
  const TimeSlotFormArgs({required this.shopId, this.slot});
  final String shopId;
  final TimeSlotModel? slot;
}

/// Owner's "+ Add Slot" / edit-capacity form. Mirrors
/// menu_item_form_screen.dart's form-screen pattern (SESSION_HANDOFF
/// _phaseAH_fixes.md §3 mirroring map) — Add mode picks a date, time,
/// and max party capacity; Edit mode only allows changing capacity,
/// since a customer may already hold a booking against the exact time.
class TimeSlotFormScreen extends ConsumerStatefulWidget {
  const TimeSlotFormScreen({super.key, required this.args});
  final TimeSlotFormArgs args;

  @override
  ConsumerState<TimeSlotFormScreen> createState() => _TimeSlotFormScreenState();
}

class _TimeSlotFormScreenState extends ConsumerState<TimeSlotFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _capacityController;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.args.slot != null;

  @override
  void initState() {
    super.initState();
    final slot = widget.args.slot;
    _capacityController = TextEditingController(
        text: slot != null ? slot.maxPartyCapacity.toString() : '4');
    if (slot != null) {
      _selectedDate = slot.slotTime;
      _selectedTime =
          TimeOfDay(hour: slot.slotTime.hour, minute: slot.slotTime.minute);
    }
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(bookingsRepositoryProvider);
      final capacity = int.parse(_capacityController.text.trim());

      if (_isEditing) {
        await repo.updateTimeSlotCapacity(
          slotId: widget.args.slot!.id,
          maxPartyCapacity: capacity,
        );
      } else {
        final slotTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        await repo.createTimeSlot(
          shopId: widget.args.shopId,
          slotTime: slotTime,
          maxPartyCapacity: capacity,
        );
      }

      ref.invalidate(ownerUpcomingSlotsProvider(widget.args.shopId));
      if (!mounted) return;
      context.pop();
    } catch (e, st) {
      debugPrint('TimeSlotFormScreen._submit failed: $e\n$st');
      setState(() => _errorMessage = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Slot' : 'Add Slot',
            style:
                AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.marginMain),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!,
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.onErrorContainer)),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                ],
                if (_isEditing) ...[
                  // Time isn't editable in edit mode — shown read-only
                  // so the owner can still see which slot they're
                  // changing capacity for.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.stackMd),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 18, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.stackSm),
                        Text(_formatDateTime(widget.args.slot!.slotTime),
                            style: AppTextStyles.bodyLg),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Time can't be changed after creation — delete and re-add if it needs to move.",
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                ] else ...[
                  _PickerRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: _formatDate(_selectedDate),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  _PickerRow(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: _selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                ],
                CustomTextField(
                  label: 'Max Party Capacity',
                  hintText: '4',
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.people_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Capacity is required';
                    }
                    final parsed = int.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid capacity';
                    }
                    if (_isEditing &&
                        parsed < widget.args.slot!.bookedCapacity) {
                      return 'Below already-booked (${widget.args.slot!.bookedCapacity})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.stackLg),
                CustomButton(
                  label: _isEditing ? 'Save Changes' : 'Add Slot',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(d)} · $hour:$minute $period';
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.stackMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.stackSm),
            Text(label, style: AppTextStyles.bodySm),
            const Spacer(),
            Text(value,
                style:
                    AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}
