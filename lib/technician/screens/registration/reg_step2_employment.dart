import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import 'registration_data.dart';
import 'registration_widgets.dart';
import 'reg_step3_security.dart';

class RegStep2Employment extends StatefulWidget {
  const RegStep2Employment({super.key, required this.api, required this.data});
  final TechnicianApi api;
  final TechRegistrationData data;
  @override
  State<RegStep2Employment> createState() => _RegStep2EmploymentState();
}

class _RegStep2EmploymentState extends State<RegStep2Employment> {
  final _empId = TextEditingController();
  String _location = '';
  final List<String> _skills = [];
  String? _error;

  static const _locations = [
    'Mumbai',
    'Delhi',
    'Bengaluru',
    'Hyderabad',
    'Chennai',
    'Kolkata',
    'Pune',
    'Ahmedabad',
    'Jaipur',
    'Lahore',
    'Karachi',
    'Islamabad',
    'Other',
  ];
  static const _allSkills = [
    'LED Signage',
    'Neon Signage',
    'Acrylic Fabrication',
    'ACP Fabrication',
    'Electrical Wiring',
    'Site Installation',
    'Sign Board Repair',
    'Flex Printing',
    'Welding',
    'Channel Letters',
    '3D Letters',
    'Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _empId.text = widget.data.employeeId;
    _location = widget.data.workLocation;
    _skills.addAll(widget.data.skills);
  }

  @override
  void dispose() {
    _empId.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_location.isEmpty) {
      setState(() => _error =
          'Work location is required. Please select your city from the dropdown.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  void _next() {
    if (!_validate()) return;
    widget.data.employeeId = _empId.text.trim();
    widget.data.workLocation = _location;
    widget.data.skills = List.from(_skills);
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegStep3Security(api: widget.api, data: widget.data),
        ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.navyDark,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios_rounded, color: AppColors.gold),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Create Account',
              style: TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.w800)),
        ),
        body: Column(children: [
          const RegProgressBar(step: 2),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Employment Details',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              const Text('Step 2 of 3 — Your work information',
                  style: TextStyle(color: AppColors.midGray, fontSize: 13)),
              const SizedBox(height: 24),

              RegField(
                  ctrl: _empId,
                  label: 'Employee ID (if issued)',
                  icon: Icons.badge_outlined,
                  hint: 'e.g. SF-T-001'),
              const SizedBox(height: 4),
              const Text('Leave blank if not yet assigned',
                  style: TextStyle(color: AppColors.midGray, fontSize: 11)),
              const SizedBox(height: 16),

              // Location
              const Text('Work Location *',
                  style: TextStyle(
                      color: AppColors.midGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _location.isEmpty
                          ? AppColors.inputBorder
                          : AppColors.gold.withValues(alpha: .4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _location.isEmpty ? null : _location,
                    hint: const Text('Select city / location',
                        style: TextStyle(color: AppColors.midGray)),
                    dropdownColor: AppColors.white,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.gold),
                    items: _locations
                        .map((l) => DropdownMenuItem(
                              value: l,
                              child: Text(l,
                                  style: const TextStyle(
                                      color: AppColors.charcoal)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _location = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Skills
              Row(children: [
                const Text('Skills',
                    style: TextStyle(
                        color: AppColors.midGray,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${_skills.length} selected',
                      style:
                          const TextStyle(color: AppColors.info, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allSkills.map((s) {
                  final sel = _skills.contains(s);
                  return GestureDetector(
                    onTap: () => setState(
                        () => sel ? _skills.remove(s) : _skills.add(s)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.gold.withValues(alpha: .15)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? AppColors.gold : AppColors.inputBorder,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (sel) ...[
                          const Icon(Icons.check_rounded,
                              size: 13, color: AppColors.gold),
                          const SizedBox(width: 4)
                        ],
                        Text(s,
                            style: TextStyle(
                              color: sel ? AppColors.navy : AppColors.midGray,
                              fontSize: 12,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.normal,
                            )),
                      ]),
                    ),
                  );
                }).toList(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                RegErrorBox(_error!)
              ],
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next: Security Setup'),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          )),
        ]),
      );
}
