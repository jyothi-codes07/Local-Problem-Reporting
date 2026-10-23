import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_theme.dart';
import '../models/report.dart';
import '../services/report_service.dart';
import '../widgets/location_map_widget.dart';
import '../widgets/report_card.dart';
import '../widgets/status_badge.dart';
import 'report_details_screen.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({
    super.key,
    this.initialCategory,
    this.onSubmitted,
  });

  final ReportCategory? initialCategory;
  final VoidCallback? onSubmitted;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final ReportService _reportService = ReportService();
  final ImagePicker _picker = ImagePicker();

  int _currentStep = 0;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController(
    text: 'MG Road, Vijayawada, Andhra Pradesh',
  );

  late ReportCategory _category;
  ReportSeverity _severity = ReportSeverity.medium;

  // Real location coordinates (Vijayawada default center for civic reporting)
  LatLng _selectedLatLng = const LatLng(16.5062, 80.6480);
  String _resolvedAddress = 'MG Road, Vijayawada, Andhra Pradesh';

  // Real photo attachment
  Uint8List? _imageBytes;
  String? _imageFileName;

  // Submitted report reference for success state
  Report? _submittedReport;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? ReportCategory.pothole;
  }

  @override
  void didUpdateWidget(covariant ReportProblemScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null &&
        widget.initialCategory != oldWidget.initialCategory) {
      _category = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageFileName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access image: $e')),
      );
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Evidence Photo',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return true;
      case 1:
        if (_titleController.text.trim().length < 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a descriptive title (at least 5 characters).')),
          );
          return false;
        }
        if (_descriptionController.text.trim().length < 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please describe what happened (at least 10 characters).')),
          );
          return false;
        }
        return true;
      case 2:
        return true;
      case 3:
        if (_addressController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please specify or confirm the problem location.')),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      String? uploadedImageUrl;
      if (_imageBytes != null) {
        uploadedImageUrl = await _reportService.uploadReportImage(_imageBytes!);
      }

      final report = await _reportService.createReport(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category.shortLabel,
        severity: _severity.label,
        location: _addressController.text.trim(),
        locationAddress: _addressController.text.trim(),
        latitude: _selectedLatLng.latitude,
        longitude: _selectedLatLng.longitude,
        imageUrl: uploadedImageUrl,
      );

      if (!mounted) return;

      setState(() => _isSubmitting = false);
      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complaint submitted: "${report.title}"'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );

      widget.onSubmitted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit complaint: $e'),
          backgroundColor: AppColors.critical,
        ),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _submittedReport = null;
      _imageBytes = null;
      _imageFileName = null;
      _severity = ReportSeverity.medium;
      _titleController.clear();
      _descriptionController.clear();
      _addressController.text = 'MG Road, Vijayawada, Andhra Pradesh';
      _selectedLatLng = const LatLng(16.5062, 80.6480);
    });
  }

  @override
  Widget build(BuildContext context) {
    // IF REPORT IS SUBMITTED, DISPLAY POLISHED SUCCESS SCREEN
    if (_submittedReport != null) {
      return _buildSuccessScreen(context);
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // STEP PROGRESS INDICATOR
          _buildStepHeader(context),

          // GUIDED STEP CONTENT
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: SingleChildScrollView(
                key: ValueKey<int>(_currentStep),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: switch (_currentStep) {
                  0 => _buildStep1Category(context),
                  1 => _buildStep2Details(context),
                  2 => _buildStep3Evidence(context),
                  3 => _buildStep4Location(context),
                  4 => _buildStep5Review(context),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ),

          // BOTTOM NAVIGATION BAR
          _buildBottomNav(context),
        ],
      ),
    );
  }

  // --- STEP 1: CATEGORY ---
  Widget _buildStep1Category(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final categoryDetails = [
      (
        ReportCategory.pothole,
        'Potholes / Roads',
        Icons.edit_road_rounded,
        const Color(0xFFD97706),
      ),
      (
        ReportCategory.garbage,
        'Garbage',
        Icons.delete_sweep_rounded,
        const Color(0xFF16A34A),
      ),
      (
        ReportCategory.streetlight,
        'Streetlights',
        Icons.lightbulb_rounded,
        const Color(0xFFCA8A04),
      ),
      (
        ReportCategory.water,
        'Water Supply',
        Icons.water_drop_rounded,
        const Color(0xFF0284C7),
      ),
      (
        ReportCategory.drainage,
        'Drainage',
        Icons.waves_rounded,
        const Color(0xFF0D9488),
      ),
      (
        ReportCategory.publicSpaces,
        'Public Spaces',
        Icons.park_rounded,
        const Color(0xFF059669),
      ),
      (
        ReportCategory.traffic,
        'Traffic / Signals',
        Icons.traffic_rounded,
        const Color(0xFFDC2626),
      ),
      (
        ReportCategory.other,
        'Other',
        Icons.category_rounded,
        const Color(0xFF7C3AED),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'STEP 1 OF 5',
          'What problem are you reporting?',
          'Select the civic category that best matches the issue.',
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 64,
          ),
          itemCount: categoryDetails.length,
          itemBuilder: (context, index) {
            final (cat, title, icon, accentColor) = categoryDetails[index];
            final isSelected = _category == cat;

            return InkWell(
              onTap: () => setState(() => _category = cat),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : scheme.outlineVariant.withValues(alpha: 0.4),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.02),
                      blurRadius: isSelected ? 6 : 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                          color: isSelected ? AppColors.dark : scheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- STEP 2: DETAILS & SEVERITY ---
  Widget _buildStep2Details(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'STEP 2 OF 5',
          'Tell us what happened',
          'Provide a clear headline and description for city authorities.',
        ),
        const SizedBox(height: 20),

        // TITLE
        TextFormField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Problem Headline',
            hintText: 'e.g. Deep pothole causing two-wheeler skids',
            prefixIcon: const Icon(Icons.title_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 18),

        // DESCRIPTION
        TextFormField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Detailed Explanation',
            alignLabelWithHint: true,
            hintText: 'Explain the issue, risks to pedestrians/vehicles, and when it began.',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 60),
              child: Icon(Icons.description_outlined),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 24),

        // SEVERITY
        Text(
          'Severity & Urgency',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: ReportSeverity.values.map((sev) {
            final isSelected = _severity == sev;
            final color = switch (sev) {
              ReportSeverity.low => AppColors.success,
              ReportSeverity.medium => AppColors.info,
              ReportSeverity.high => AppColors.warning,
              ReportSeverity.critical => AppColors.critical,
            };

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _severity = sev),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : Colors.black.withValues(alpha: 0.12),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sev.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? color : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- STEP 3: REAL EVIDENCE INPUT ---
  Widget _buildStep3Evidence(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'STEP 3 OF 5',
          'Add photo evidence',
          'A photo helps municipal teams verify the problem and dispatch correct tools.',
        ),
        const SizedBox(height: 20),

        if (_imageBytes != null) ...[
          // DISPLAY ACTUAL SELECTED IMAGE
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(_imageBytes!, fit: BoxFit.cover),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.accent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _imageFileName ?? 'Evidence attached',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showImagePickerSheet,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Change Photo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _imageBytes = null;
                      _imageFileName = null;
                    });
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.critical,
                    side: const BorderSide(color: AppColors.critical),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // LARGE IMAGE UPLOAD AREA WITH TWO WORKING BUTTONS
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Capture or attach problem evidence',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Visual evidence increases authority dispatch speed by 3x.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),

                // TWO WORKING OPTIONS
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text(
                          'TAKE PHOTO',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text(
                          'FROM GALLERY',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- STEP 4: INTERACTIVE LOCATION PICKER ---
  Widget _buildStep4Location(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'STEP 4 OF 5',
          'Where is the problem?',
          'Move the interactive map or use GPS to pinpoint exact coordinates.',
        ),
        const SizedBox(height: 18),

        // INTERACTIVE MAP WITH OSM NOMINATIM REVERSE GEOCODING
        LocationMapPicker(
          initialPosition: _selectedLatLng,
          initialAddress: _resolvedAddress,
          onLocationChanged: (point) {
            setState(() {
              _selectedLatLng = point;
            });
          },
          onAddressResolved: (address) {
            setState(() {
              _resolvedAddress = address;
              _addressController.text = address;
            });
          },
          onLocationConfirmed: (pos, address) {
            setState(() {
              _selectedLatLng = pos;
              _resolvedAddress = address;
              _addressController.text = address;
            });
          },
        ),

        const SizedBox(height: 16),

        // EDITABLE ADDRESS / LANDMARK FIELD
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Landmark / Detailed Address Note',
            hintText: 'e.g. Near City Hospital Gate 2',
            prefixIcon: const Icon(Icons.edit_location_alt_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // --- STEP 5: REVIEW REPORT ---
  Widget _buildStep5Review(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
          'STEP 5 OF 5',
          'Review your report',
          'Please verify details before submitting to central ward authorities.',
        ),
        const SizedBox(height: 18),

        // COMPREHENSIVE SUMMARY CARD
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconForCategory(_category), size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            _category.label,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SeverityBadge(severity: _severity),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  _titleController.text.trim().isNotEmpty
                      ? _titleController.text.trim()
                      : 'Untitled Complaint',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  _descriptionController.text.trim().isNotEmpty
                      ? _descriptionController.text.trim()
                      : 'No description provided.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const Divider(height: 28),

                // ADDRESS & LOCATION SUMMARY
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Incident Location',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _addressController.text.trim(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_selectedLatLng.latitude.toStringAsFixed(4)}, ${_selectedLatLng.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_imageBytes != null) ...[
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Attached Evidence',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _imageBytes!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- POLISHED SUCCESS SCREEN ---
  Widget _buildSuccessScreen(BuildContext context) {
    final report = _submittedReport!;
    final reportCode = 'LF-${report.id.substring(0, 6).toUpperCase()}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // ANIMATED CHECK CIRCLE
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.success, width: 3),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Report Submitted Successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 8),

            const Text(
              'Your complaint has been sent to the ward authority Central Command for review and dispatch.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),

            // REPORT REFERENCE CARD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'COMPLAINT TRACKING ID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reportCode,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ACTIONS
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReportDetailsScreen(report: report),
                    ),
                  );
                  _resetForm();
                  widget.onSubmitted?.call();
                },
                icon: const Icon(Icons.remove_red_eye_rounded),
                label: const Text('View My Report', style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _resetForm();
                  widget.onSubmitted?.call();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP HEADER & TITLE ---
  Widget _buildStepHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(5, (index) {
              final isPassed = index <= _currentStep;

              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 4 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isPassed ? AppColors.primary : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String badge, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  // --- BOTTOM NAV BAR ---
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back'),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : _currentStep == 4
                        ? _submitReport
                        : _nextStep,
                style: FilledButton.styleFrom(
                  backgroundColor: _currentStep == 4 ? AppColors.dark : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _currentStep == 4 ? 'SUBMIT CIVIC REPORT' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
