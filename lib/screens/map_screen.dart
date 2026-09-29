import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import '../models/dropoff_point.dart';
import '../services/ewaste_service.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/launcher.dart';
import '../widgets/app_card.dart';
import '../widgets/status_chip.dart';
import 'report_ewaste_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _kigali = LatLng(
    AppConstants.kigaliCenterLat,
    AppConstants.kigaliCenterLng,
  );
  static const _districtFilters = ['All', ...AppConstants.districts];
  static const _listPanelFraction = 0.36;
  static const _detailPanelHeight = 320.0;

  final _mapController = MapController();
  final _searchController = TextEditingController();
  bool _mapReady = false;
  String _district = 'All';
  bool _openNowOnly = false;
  String _query = '';
  DropoffPoint? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = context.read<LocationService>();
      if (location.status == LocationStatus.unknown) location.request();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  List<DropoffPoint> _filter(List<DropoffPoint> points, LocationService loc) {
    final query = _query.trim().toLowerCase();
    final filtered = points.where((p) {
      if (_district != 'All' && p.district != _district) return false;
      if (_openNowOnly && !p.isOpenNow) return false;
      if (query.isNotEmpty &&
          !p.name.toLowerCase().contains(query) &&
          !p.address.toLowerCase().contains(query) &&
          !p.typeLabel.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
    return loc.sortByDistance(filtered);
  }

  /// The map runs under the search bar and the bottom panel, so camera moves
  /// are padded to keep targets in the visible gap between them.
  EdgeInsets _visibleArea({required bool detail}) {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top + 130;
    final panel =
        detail ? _detailPanelHeight : size.height * _listPanelFraction;
    return EdgeInsets.fromLTRB(40, top, 40, panel + 40);
  }

  void _focus(LatLng target, {double zoom = 15, bool detail = false}) {
    if (!_mapReady) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [target],
        padding: _visibleArea(detail: detail),
        maxZoom: zoom,
        minZoom: zoom,
      ),
    );
  }

  void _select(DropoffPoint point) {
    FocusScope.of(context).unfocus();
    setState(() => _selected = point);
    _focus(LatLng(point.latitude, point.longitude), detail: true);
  }

  void _fitAll(List<DropoffPoint> points, LatLng? me) {
    if (!_mapReady) return;
    final coords = [
      for (final p in points) LatLng(p.latitude, p.longitude),
      if (me != null) me,
    ];
    if (coords.isEmpty) return;
    if (coords.length == 1) {
      _focus(coords.first, detail: _selected != null);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: coords,
        padding: _visibleArea(detail: _selected != null),
        maxZoom: 16,
      ),
    );
  }

  Future<void> _locateMe() async {
    final location = context.read<LocationService>();
    final messenger = ScaffoldMessenger.of(context);
    final position = await location.request();
    if (position != null) {
      _focus(position, detail: _selected != null);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(location.statusMessage),
          action: location.canOpenSettings
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: location.openSettings,
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EwasteService>();
    final location = context.watch<LocationService>();
    final points = _filter(service.dropoffPoints, location);
    final selected = _selected;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _kigali,
                  initialZoom: 12.4,
                  minZoom: 9,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _mapReady = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _fitAll(points, null);
                    });
                  },
                  onTap: (_, __) {
                    FocusScope.of(context).unfocus();
                    if (_selected != null) setState(() => _selected = null);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'rw.ecocollect.app',
                    maxZoom: 19,
                  ),
                  if (location.position != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: location.position!,
                          width: 30,
                          height: 30,
                          child: const _UserDot(),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final point in points)
                        Marker(
                          point: LatLng(point.latitude, point.longitude),
                          width: 48,
                          height: 58,
                          alignment: Alignment.topCenter,
                          child: _PointPin(
                            point: point,
                            selected: selected?.id == point.id,
                            onTap: () => _select(point),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Overlays sit in the gap above the panel; empty areas let
            // gestures through to the map underneath.
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // Search and filters
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: AppShadows.card,
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (v) =>
                                        setState(() => _query = v),
                                    textInputAction: TextInputAction.search,
                                    decoration: InputDecoration(
                                      hintText: 'Search drop-off points',
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                          width: 1.6,
                                        ),
                                      ),
                                      suffixIcon: _query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear',
                                              icon: const Icon(
                                                  Icons.close_rounded),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() => _query = '');
                                              },
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 38,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  clipBehavior: Clip.none,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  children: [
                                    _FilterPill(
                                      label: 'Open now',
                                      icon: Icons.schedule_rounded,
                                      selected: _openNowOnly,
                                      onTap: () => setState(
                                        () => _openNowOnly = !_openNowOnly,
                                      ),
                                    ),
                                    for (final d in _districtFilters)
                                      _FilterPill(
                                        label: d,
                                        selected: _district == d,
                                        onTap: () {
                                          setState(() {
                                            _district = d;
                                            _selected = null;
                                          });
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            _fitAll(
                                              _filter(service.dropoffPoints,
                                                  location),
                                              null,
                                            );
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Map controls
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Column(
                          children: [
                            _MapButton(
                              tooltip: 'Show all points',
                              icon: Icons.zoom_out_map_rounded,
                              onPressed: () =>
                                  _fitAll(points, location.position),
                            ),
                            const SizedBox(height: 10),
                            _MapButton(
                              tooltip: 'My location',
                              icon: Icons.my_location_rounded,
                              loading: location.isLoading,
                              onPressed: _locateMe,
                            ),
                          ],
                        ),
                      ),
                      // OpenStreetMap attribution (required by the tile policy)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: () => openExternalUrl(
                            context,
                            'https://www.openstreetmap.org/copyright',
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A0B3D2C),
                        blurRadius: 20,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: selected != null
                        ? _PointDetail(
                            point: selected,
                            distance: location.distanceTo(selected),
                            onClose: () => setState(() => _selected = null),
                          )
                        : _PointList(
                            points: points,
                            location: location,
                            onSelect: _select,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PointList extends StatelessWidget {
  final List<DropoffPoint> points;
  final LocationService location;
  final ValueChanged<DropoffPoint> onSelect;

  const _PointList({
    required this.points,
    required this.location,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.sizeOf(context).height * _MapScreenState._listPanelFraction;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          const _Handle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${points.length} drop-off point${points.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  location.hasPosition ? 'Nearest first' : 'Kigali',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: points.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No points match your filters.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: points.length,
                    separatorBuilder: (_, __) => const Divider(indent: 76),
                    itemBuilder: (context, i) {
                      final point = points[i];
                      final distance = location.distanceTo(point);
                      return ListTile(
                        onTap: () => onSelect(point),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: IconBadge(
                          icon: point.typeIcon,
                          color: point.typeColor,
                          size: 44,
                        ),
                        title: Text(
                          point.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [
                              if (distance != null) formatDistance(distance),
                              point.isOpenNow ? 'Open now' : 'Closed',
                              point.address,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PointDetail extends StatelessWidget {
  final DropoffPoint point;
  final double? distance;
  final VoidCallback onClose;

  const _PointDetail({
    required this.point,
    required this.distance,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Handle(),
          Row(
            children: [
              IconBadge(icon: point.typeIcon, color: point.typeColor, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${point.typeLabel} · ${point.district}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OpenStatusChip(point: point),
              if (distance != null)
                TagChip(
                  label: '${formatDistance(distance!)} away',
                  icon: Icons.near_me_rounded,
                  color: AppColors.sky,
                  background: AppColors.skySoft,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(icon: Icons.place_outlined, text: point.address),
          _InfoLine(
            icon: Icons.schedule_rounded,
            text: '${point.operatingHours}\n${point.openStatusLabel}',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => openDirections(context, point),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Directions'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportEwasteScreen(initialPoint: point),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Drop off here'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        elevation: 2,
        shadowColor: const Color(0x330B3D2C),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
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

class _MapButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool loading;

  const _MapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x400B3D2C),
      child: IconButton(
        tooltip: tooltip,
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

class _PointPin extends StatelessWidget {
  final DropoffPoint point;
  final bool selected;
  final VoidCallback onTap;

  const _PointPin({
    required this.point,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = point.typeColor;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? 46 : 38,
            height: selected ? 46 : 38,
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              point.typeIcon,
              size: selected ? 22 : 19,
              color: selected ? Colors.white : color,
            ),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _PinTipPainter(color),
          ),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  final Color color;

  _PinTipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTipPainter oldDelegate) => oldDelegate.color != color;
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2563EB).withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}
