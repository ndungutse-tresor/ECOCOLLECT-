import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:provider/provider.dart';
import '../models/dropoff_point.dart';
import '../models/ewaste_item.dart';
import '../services/ewaste_service.dart';
import '../services/location_service.dart';
import '../services/photo_storage.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/photo_view.dart';
import '../widgets/status_chip.dart';
import 'report_success_screen.dart';

class ReportEwasteScreen extends StatefulWidget {
  final DisposalMethod initialMethod;
  final DropoffPoint? initialPoint;

  const ReportEwasteScreen({
    super.key,
    this.initialMethod = DisposalMethod.dropoff,
    this.initialPoint,
  });

  @override
  State<ReportEwasteScreen> createState() => _ReportEwasteScreenState();
}

class _ReportEwasteScreenState extends State<ReportEwasteScreen> {
  static const _stepLabels = ['Category', 'Details', 'Hand-over', 'Review'];

  int _step = 0;
  bool _forward = true;
  EwasteCategory? _category;
  int _quantity = 1;
  ItemCondition _condition = ItemCondition.dead;
  String? _photoPath;
  bool _pickingPhoto = false;
  late DisposalMethod _method;
  DropoffPoint? _point;
  late DateTime _pickupDate;
  String _timeSlot = PickupDetails.timeSlots.first;
  bool _locatingAddress = false;
  bool _submitting = false;

  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _point = widget.initialPoint;
    _method = _point != null ? DisposalMethod.dropoff : widget.initialMethod;
    final now = DateTime.now();
    _pickupDate = DateTime(now.year, now.month, now.day + 1);
    _phoneController.text = context.read<EwasteService>().profile?.phone ?? '';
  }

  @override
  void dispose() {
    _descController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  double get _weight => double.parse(
        ((_category?.avgWeightKg ?? 0) * _quantity).toStringAsFixed(2),
      );

  int get _points => EwasteItem.pointsFor(_weight, _quantity);

  bool get _pickupValid =>
      _addressController.text.trim().length >= 3 &&
      isValidRwandaPhone(_phoneController.text);

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _category != null;
      case 1:
        return true;
      case 2:
        return _method == DisposalMethod.dropoff
            ? _point != null
            : _pickupValid;
      default:
        return !_submitting;
    }
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _next() => _step < 3 ? _goTo(_step + 1) : _submit();

  void _back() => _step > 0 ? _goTo(_step - 1) : Navigator.pop(context);

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _pickingPhoto = true);
    try {
      final path = await PhotoStorage.pick(source);
      if (path != null && mounted) setState(() => _photoPath = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not open the camera or gallery. Check app permissions.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _useCurrentAddress() async {
    final location = context.read<LocationService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locatingAddress = true);
    final position = await location.request();
    if (position == null) {
      messenger.showSnackBar(SnackBar(content: Text(location.statusMessage)));
    } else {
      String? address;
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final p = places.first;
          address = [p.street, p.subLocality, p.locality]
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .toSet()
              .join(', ');
        }
      } catch (_) {
        // Reverse geocoding is unavailable on some platforms (e.g. web).
      }
      _addressController.text = (address == null || address.isEmpty)
          ? 'Near ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
          : address;
    }
    if (mounted) setState(() => _locatingAddress = false);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final service = context.read<EwasteService>();
    final navigator = Navigator.of(context);
    final description = _descController.text.trim();

    final item = EwasteItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      categoryId: _category!.id,
      quantity: _quantity,
      estimatedWeightKg: _weight,
      condition: _condition,
      photoPath: _photoPath,
      description: description.isEmpty ? null : description,
      disposalMethod: _method,
      dropoffPointId: _method == DisposalMethod.dropoff ? _point?.id : null,
      pickup: _method == DisposalMethod.pickup
          ? PickupDetails(
              address: _addressController.text.trim(),
              phone: _phoneController.text.trim(),
              date: _pickupDate,
              timeSlot: _timeSlot,
            )
          : null,
      createdAt: DateTime.now(),
    );

    await service.addItem(item);
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => ReportSuccessScreen(itemId: item.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _step == 0 ? 'Close' : 'Back',
            icon: Icon(
              _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
            ),
            onPressed: _back,
          ),
          title: const Text('Report e-waste'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Step ${_step + 1} of 4',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _StepProgress(step: _step, labels: _stepLabels),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_step);
                  final dx = (_forward == incoming) ? 0.08 : -0.08;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(dx, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(),
                ),
              ),
            ),
            _BottomActions(
              step: _step,
              enabled: _canContinue,
              loading: _submitting,
              onBack: _step == 0 ? null : _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildCategoryStep();
      case 1:
        return _buildDetailsStep();
      case 2:
        return _buildDisposalStep();
      default:
        return _buildReviewStep();
    }
  }

  // Step 1 ------------------------------------------------------------------

  Widget _buildCategoryStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _StepHeading(
          title: 'What are you recycling?',
          subtitle: 'Choose the category that best matches your item.',
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 152,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: EwasteCategory.categories.length,
          itemBuilder: (context, i) {
            final category = EwasteCategory.categories[i];
            return _CategoryTile(
              category: category,
              selected: _category?.id == category.id,
              onTap: () {
                setState(() => _category = category);
                Future.delayed(const Duration(milliseconds: 220), () {
                  if (mounted && _step == 0) _goTo(1);
                });
              },
            );
          },
        ),
      ],
    );
  }

  // Step 2 ------------------------------------------------------------------

  Widget _buildDetailsStep() {
    final category = _category!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              IconBadge(icon: category.icon, color: category.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      category.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                  onPressed: () => _goTo(0), child: const Text('Change')),
            ],
          ),
        ),
        const _Label('How many items?'),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          _quantity == 1 ? 'item' : 'items',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.add_rounded,
                    onPressed: _quantity < 99
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.scale_rounded,
                      label: 'Est. weight',
                      value: formatKg(_weight),
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.border),
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.stars_rounded,
                      label: 'EcoPoints',
                      value: '+$_points',
                      iconColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _Label('Condition'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ItemCondition.values.map((c) {
            final selected = c == _condition;
            return ChoiceChip(
              label: Text(c.label),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              onSelected: (_) => setState(() => _condition = c),
            );
          }).toList(),
        ),
        const _Label('Photo (optional)'),
        _buildPhotoPicker(),
        const _Label('Description (optional)'),
        TextField(
          controller: _descController,
          maxLines: 3,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. 2 old Nokia phones, one cracked Samsung…',
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          color: AppColors.primarySoft,
          shadow: null,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.tip,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPicker() {
    if (_photoPath != null) {
      return Stack(
        children: [
          PhotoView(path: _photoPath!, height: 190, width: double.infinity),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton.filled(
              tooltip: 'Remove photo',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
              ),
              onPressed: () => setState(() => _photoPath = null),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: const Text('Retake'),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.4,
        ),
      ),
      child: _pickingPhoto
          ? const SizedBox(
              height: 92,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                const Text(
                  'A photo helps collectors know what to expect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_rounded,
                            color: AppColors.primary),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded,
                            color: AppColors.primary),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // Step 3 ------------------------------------------------------------------

  Widget _buildDisposalStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _StepHeading(
          title: 'How will you hand it over?',
          subtitle: 'Bring it to a collection point or book a free pickup.',
        ),
        Row(
          children: [
            Expanded(
              child: _MethodCard(
                icon: Icons.place_rounded,
                title: 'Drop-off',
                subtitle: 'Bring it to a nearby point',
                color: AppColors.primary,
                selected: _method == DisposalMethod.dropoff,
                onTap: () => setState(() => _method = DisposalMethod.dropoff),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MethodCard(
                icon: Icons.local_shipping_rounded,
                title: 'Home pickup',
                subtitle: 'A collector comes to you',
                color: AppColors.warning,
                selected: _method == DisposalMethod.pickup,
                onTap: () => setState(() => _method = DisposalMethod.pickup),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_method == DisposalMethod.dropoff)
          _buildDropoffPicker()
        else
          _buildPickupForm(),
      ],
    );
  }

  Widget _buildDropoffPicker() {
    final service = context.read<EwasteService>();
    final location = context.watch<LocationService>();
    final points = location.sortByDistance(service.dropoffPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Choose a drop-off point',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              if (location.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!location.hasPosition)
                TextButton.icon(
                  onPressed: location.request,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Sort by distance'),
                ),
            ],
          ),
        ),
        for (final point in points)
          _PointOption(
            point: point,
            distance: location.distanceTo(point),
            selected: _point?.id == point.id,
            onTap: () => setState(() => _point = point),
          ),
      ],
    );
  }

  Widget _buildPickupForm() {
    final days = List.generate(7, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day + 1 + i);
    });
    final phoneText = _phoneController.text;
    final phoneError =
        phoneText.trim().isNotEmpty && !isValidRwandaPhone(phoneText)
            ? 'Enter a valid Rwandan mobile number'
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Pickup address'),
        TextField(
          controller: _addressController,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'House no., street, sector',
            prefixIcon: const Icon(Icons.home_outlined),
            suffixIcon: _locatingAddress
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Use my current location',
                    onPressed: _useCurrentAddress,
                    icon: const Icon(Icons.my_location_rounded,
                        color: AppColors.primary),
                  ),
          ),
        ),
        const _Label('Phone number'),
        TextField(
          controller: _phoneController,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
          ],
          decoration: InputDecoration(
            hintText: '07X XXX XXXX',
            prefixIcon: const Icon(Icons.phone_outlined),
            errorText: phoneError,
          ),
        ),
        const _Label('Preferred day'),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = days[i];
              final selected = DateUtils.isSameDay(day, _pickupDate);
              const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _pickupDate = day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        i == 0 ? 'Tmrw' : names[day.weekday - 1],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const _Label('Time slot'),
        for (final slot in PickupDetails.timeSlots)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              shadow: null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: Border.all(
                color: slot == _timeSlot ? AppColors.primary : AppColors.border,
                width: slot == _timeSlot ? 1.6 : 1,
              ),
              onTap: () => setState(() => _timeSlot = slot),
              child: Row(
                children: [
                  Icon(
                    slot == _timeSlot
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: slot == _timeSlot
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Text(slot,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        AppCard(
          color: AppColors.warningSoft,
          shadow: null,
          padding: const EdgeInsets.all(14),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.warning),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pickups are free. A registered collector will call you within 24 hours to confirm.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 4 ------------------------------------------------------------------

  Widget _buildReviewStep() {
    final category = _category!;
    final dropoff = _method == DisposalMethod.dropoff;
    final description = _descController.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _StepHeading(
          title: 'Review your report',
          subtitle: 'Make sure everything looks right before submitting.',
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_photoPath != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: PhotoView(path: _photoPath!, height: 160),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                child: Row(
                  children: [
                    IconBadge(icon: category.icon, color: category.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$_quantity item${_quantity == 1 ? '' : 's'} · ${formatKg(_weight)} · ${_condition.label}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _goTo(1),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
              if (description.isNotEmpty) ...[
                const Divider(),
                _ReviewRow(
                  icon: Icons.notes_rounded,
                  title: 'Note',
                  body: description,
                ),
              ],
              const Divider(),
              _ReviewRow(
                icon: dropoff
                    ? Icons.place_rounded
                    : Icons.local_shipping_rounded,
                title: dropoff ? 'Drop-off point' : 'Home pickup',
                body: dropoff
                    ? '${_point!.name}\n${_point!.address} · ${_point!.operatingHours}'
                    : '${_addressController.text.trim()}\n'
                        '${formatShortDay(_pickupDate)} · ${_timeSlot.split(' · ').first}\n'
                        '${_phoneController.text.trim()}',
                onEdit: () => _goTo(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accentSoft, Color(0xFFFFEBC2)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const IconBadge(
                icon: Icons.stars_rounded,
                color: AppColors.accent,
                background: Colors.white,
                size: 46,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You’ll earn $_points EcoPoints',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7C4A03),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Credited as soon as your e-waste is handed over.',
                      style:
                          TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Building blocks

class _StepProgress extends StatelessWidget {
  final int step;
  final List<String> labels;

  const _StepProgress({required this.step, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < step;
          final active = i == step;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < labels.length - 1 ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    decoration: BoxDecoration(
                      color:
                          done || active ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: done || active
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final int step;
  final bool enabled;
  final bool loading;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  const _BottomActions({
    required this.step,
    required this.enabled,
    required this.loading,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Continue', 'Continue', 'Review report', 'Submit report'];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (onBack != null) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: enabled ? onNext : null,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(labels[step]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StepHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final EwasteCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? category.color.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? category.color : AppColors.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected ? null : AppShadows.soft,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(icon: category.icon, color: category.color),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.check_circle_rounded,
                          color: category.color),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  category.name,
                  maxLines: 2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
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

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _RoundButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      iconSize: 26,
      style: IconButton.styleFrom(
        minimumSize: const Size(52, 52),
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.surfaceMuted,
        disabledForegroundColor: AppColors.textMuted,
      ),
      icon: Icon(icon),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(icon: icon, color: color, size: 42),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: selected ? color : AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _PointOption extends StatelessWidget {
  final DropoffPoint point;
  final double? distance;
  final bool selected;
  final VoidCallback onTap;

  const _PointOption({
    required this.point,
    required this.distance,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      shadow: selected ? null : AppShadows.soft,
      color: selected ? AppColors.primarySoft : AppColors.surface,
      border: Border.all(
        color: selected ? AppColors.primary : Colors.transparent,
        width: 1.6,
      ),
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(icon: point.typeIcon, color: point.typeColor, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  distance != null
                      ? '${formatDistance(distance!)} · ${point.address}'
                      : point.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OpenStatusChip(point: point),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        point.operatingHours,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? AppColors.primary : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onEdit;

  const _ReviewRow({
    required this.icon,
    required this.title,
    required this.body,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}
