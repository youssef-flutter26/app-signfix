import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SignBoardTextDesign — data model returned when user taps "Continue"
// ─────────────────────────────────────────────────────────────────────────────
class SignBoardTextDesign {
  const SignBoardTextDesign({
    required this.text,
    required this.fontFamily,
    required this.color,
    this.fontSize = 32,
  });
  final String text;
  final String fontFamily;
  final Color color;
  final double fontSize;
}

// ─────────────────────────────────────────────────────────────────────────────
//  TextDesignerScreen
//  Type text → pick font → pick color → adjust size → live neon preview
//  Acrylic Backing Size Calculator shown below preview (real-time)
// ─────────────────────────────────────────────────────────────────────────────
class TextDesignerScreen extends StatefulWidget {
  const TextDesignerScreen({super.key, this.initial});
  final SignBoardTextDesign? initial;

  @override
  State<TextDesignerScreen> createState() => _TextDesignerScreenState();
}

class _TextDesignerScreenState extends State<TextDesignerScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  String _font = 'Pacifico';
  Color _color = AppColors.navy;
  double _fontSize = 32;
  bool _showMore = false;

  // ── Available fonts ───────────────────────────────────────────────────────
  static const _fonts = [
    'Pacifico',
    'Dancing Script',
    'Great Vibes',
    'Satisfy',
    'Caveat',
    'Permanent Marker',
    'Shadows Into Light',
    'Sacramento',
    'Yellowtail',
    'Kaushan Script',
    'Courgette',
    'Lobster',
  ];

  // Signboard preview colors stay within the approved brand palette.
  static const _presetColors = AppColors.signageColors;
  static const _customColors = AppColors.additionalSignageColors;

  Color _contrastingBrandColor(Color color) {
    final luminance = color.computeLuminance();
    double contrastAgainst(Color background) {
      final backgroundLuminance = background.computeLuminance();
      final lighter =
          backgroundLuminance > luminance ? backgroundLuminance : luminance;
      final darker =
          backgroundLuminance > luminance ? luminance : backgroundLuminance;
      return (lighter + 0.05) / (darker + 0.05);
    }

    final contrastOnWhite = contrastAgainst(AppColors.white);
    final contrastOnNavy = contrastAgainst(AppColors.navy);
    return contrastOnWhite > contrastOnNavy ? AppColors.white : AppColors.navy;
  }

  // ── Glow animation ────────────────────────────────────────────────────────
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _ctrl.text = widget.initial!.text;
      _font = widget.initial!.fontFamily;
      _color = widget.initial!.color;
      _fontSize = widget.initial!.fontSize;
    }
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 6, end: 22)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // Build Google Font style for preview
  TextStyle _buildStyle(double size, Color color) {
    try {
      switch (_font) {
        case 'Pacifico':
          return GoogleFonts.pacifico(fontSize: size, color: color);
        case 'Dancing Script':
          return GoogleFonts.dancingScript(
              fontSize: size, color: color, fontWeight: FontWeight.w700);
        case 'Great Vibes':
          return GoogleFonts.greatVibes(fontSize: size, color: color);
        case 'Satisfy':
          return GoogleFonts.satisfy(fontSize: size, color: color);
        case 'Caveat':
          return GoogleFonts.caveat(
              fontSize: size, color: color, fontWeight: FontWeight.w700);
        case 'Permanent Marker':
          return GoogleFonts.permanentMarker(fontSize: size, color: color);
        case 'Shadows Into Light':
          return GoogleFonts.shadowsIntoLight(fontSize: size, color: color);
        case 'Sacramento':
          return GoogleFonts.sacramento(fontSize: size, color: color);
        case 'Yellowtail':
          return GoogleFonts.yellowtail(fontSize: size, color: color);
        case 'Kaushan Script':
          return GoogleFonts.kaushanScript(fontSize: size, color: color);
        case 'Courgette':
          return GoogleFonts.courgette(fontSize: size, color: color);
        case 'Lobster':
          return GoogleFonts.lobster(fontSize: size, color: color);
        default:
          return TextStyle(fontSize: size, color: color);
      }
    } catch (_) {
      return TextStyle(fontSize: size, color: color);
    }
  }

  void _done() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please type your sign board text.')));
      return;
    }
    Navigator.pop(
        context,
        SignBoardTextDesign(
            text: text, fontFamily: _font, color: _color, fontSize: _fontSize));
  }

  @override
  Widget build(BuildContext context) {
    final previewText = _ctrl.text.isEmpty ? 'YOUR TEXT HERE' : _ctrl.text;
    final allColors =
        _showMore ? [..._presetColors, ..._customColors] : _presetColors;

    return Scaffold(
      backgroundColor: AppColors.softGray,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        foregroundColor: AppColors.navy,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.goldDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Design Your Sign',
            style:
                TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text('Type your text, pick a font & color.',
                  style: TextStyle(color: AppColors.midGray, fontSize: 13)),
              const SizedBox(height: 16),

              // ── Text input (maxLength = 35 per requirements) ──────────────
              TextField(
                controller: _ctrl,
                maxLength: 35, // MUST be 35 — allows testing 21+ logic
                style: const TextStyle(color: AppColors.textBody, fontSize: 16),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Type your text',
                  counterStyle: const TextStyle(color: AppColors.midGray),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon:
                              const Icon(Icons.clear, color: AppColors.midGray),
                          onPressed: () => setState(() => _ctrl.clear()),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // ── Live Neon Preview (pulsing glow animation) ────────────────
              AnimatedBuilder(
                animation: _glow,
                builder: (_, __) => Container(
                  key: const ValueKey('sign-text-preview'),
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                  decoration: BoxDecoration(
                    color: AppColors.signPreviewBackground(_color),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _color.withValues(alpha: .3)),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: .15),
                        blurRadius: _glow.value * 2,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      previewText,
                      style: _buildStyle(_fontSize, _color).copyWith(
                        shadows: [
                          Shadow(
                              color: _color.withValues(alpha: .9),
                              blurRadius: _glow.value),
                          Shadow(
                              color: _color.withValues(alpha: .6),
                              blurRadius: _glow.value * 2),
                          Shadow(
                              color: _color.withValues(alpha: .3),
                              blurRadius: _glow.value * 4),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Font Size Slider (14 → 64) ────────────────────────────────
              Row(children: [
                const Text('Text Size',
                    style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: Text(
                    '${_fontSize.round()}px',
                    style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.text_fields,
                    size: 16, color: AppColors.midGray),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor:
                          AppColors.gold, // AppColors — no raw hex
                      inactiveTrackColor: AppColors.cardBorder,
                      thumbColor: AppColors.gold,
                      overlayColor: AppColors.gold.withValues(alpha: .2),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _fontSize,
                      min: 14,
                      max: 64,
                      divisions: 25,
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                ),
                const Icon(Icons.text_fields,
                    size: 24, color: AppColors.midGray),
              ]),
              const SizedBox(height: 24),

              // ── Pick Font ─────────────────────────────────────────────────
              const Text('Pick Your Font',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.8,
                ),
                itemCount: _fonts.length,
                itemBuilder: (_, i) {
                  final f = _fonts[i];
                  final selected = _font == f;
                  return GestureDetector(
                    onTap: () => setState(() => _font = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.gold : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.goldDark
                              : AppColors.cardBorder,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: _color.withValues(alpha: .2),
                                    blurRadius: 8)
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          f.length > 13 ? '${f.substring(0, 12)}…' : f,
                          style: _buildStyle(15,
                              selected ? AppColors.navy : AppColors.charcoal),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Pick Color ────────────────────────────────────────────────
              const Text('Pick a Color',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...allColors.map((c) {
                    final selected = _color.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      key: ValueKey('designer-color-${c.toARGB32()}'),
                      onTap: () => setState(() => _color = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? _contrastingBrandColor(c)
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: c.withValues(alpha: selected ? .6 : .25),
                              blurRadius: selected ? 14 : 4,
                            ),
                          ],
                        ),
                        child: selected
                            ? Icon(Icons.check_rounded,
                                color: _contrastingBrandColor(c), size: 20)
                            : null,
                      ),
                    );
                  }),
                  // Show more / less toggle
                  GestureDetector(
                    onTap: () => setState(() => _showMore = !_showMore),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Icon(
                        _showMore
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.navy,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _showMore ? 'Tap ↑ to show fewer' : 'Tap + for more colors',
                style: const TextStyle(color: AppColors.midGray, fontSize: 11),
              ),
              const SizedBox(height: 30),

              // ── Acrylic Backing Size Calculator ──────────────────────────
              _AcrylicSizeCard(text: _ctrl.text),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // ── Continue button ───────────────────────────────────────────────
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: GestureDetector(
              onTap: _done,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: .4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '→  Continue',
                      style: TextStyle(
                        color: AppColors.navyDeep,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AcrylicSize — immutable data model for one board size tier
// ─────────────────────────────────────────────────────────────────────────────
class _AcrylicSize {
  const _AcrylicSize({
    required this.label, // display string e.g. "3 × 1 ft"
    required this.sqft, // total area in sq ft
    required this.width, // board width in ft  (double to support 1.5)
    required this.height, // board height in ft (double to support 1.5)
    this.isCustom = false,
  });
  final String label;
  final double sqft;
  final double width; // double — NOT int (4 × 1.5 needs fractional height)
  final double height;
  final bool isCustom;
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AcrylicSizeCard
//  Shown below the neon preview; updates in real-time as user types.
//  Strictly uses AppColors for all UI (no raw hex in UI layer).
// ─────────────────────────────────────────────────────────────────────────────
class _AcrylicSizeCard extends StatelessWidget {
  const _AcrylicSizeCard({required this.text});
  final String text;

  // ── CORRECT character count: ignore ONLY spaces ───────────────────────────
  // DO NOT use [^a-zA-Z0-9] — that ignores symbols like '!', '@', '#'.
  // Formula: remove whitespace, count what's left.
  static int _charCount(String t) => t.replaceAll(RegExp(r'\s+'), '').length;

  // ── Size mapping (per business rules) ────────────────────────────────────
  static _AcrylicSize? _calcSize(String t) {
    final n = _charCount(t);
    if (n == 0) return null;
    if (n <= 5) {
      return const _AcrylicSize(
          label: '1 × 1 ft', sqft: 1, width: 1, height: 1);
    }
    if (n <= 10) {
      return const _AcrylicSize(
          label: '2 × 1 ft', sqft: 2, width: 2, height: 1);
    }
    if (n <= 15) {
      return const _AcrylicSize(
          label: '3 × 1 ft', sqft: 3, width: 3, height: 1);
    }
    if (n <= 20) {
      return const _AcrylicSize(
          label: '4 × 1.5 ft', sqft: 6, width: 4, height: 1.5);
    }
    return const _AcrylicSize(
        label: '5 × 2 ft', sqft: 10, width: 5, height: 2, isCustom: true);
  }

  // ── Pricing: ₹1,500 / sq ft ──────────────────────────────────────────────
  static const double _rate = 1500;

  static String _price(_AcrylicSize s) {
    if (s.isCustom) return 'Contact for Quote';
    final p = (s.sqft * _rate).round();
    // Format with commas e.g. 9,000
    return '₹${p.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  // ── Proportional board diagram ────────────────────────────────────────────
  Widget _diagram(_AcrylicSize s, Color accent) {
    const maxW = 72.0;
    final ratio = s.height / s.width; // e.g. 1.5/4 = 0.375
    final h = (maxW * ratio).clamp(14.0, 72.0);
    return Container(
      width: maxW,
      height: h,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: .6), width: 1.5),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .25), blurRadius: 8)
        ],
      ),
      child: Center(
        child: Text(s.label,
            style: TextStyle(
                color: accent, fontSize: 9, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _calcSize(text);
    final count = _charCount(text);
    final isEmpty = text.trim().isEmpty;

    // Accent color follows progress — all from AppColors
    final Color accent = size == null
        ? AppColors.midGray
        : size.isCustom
            ? AppColors.danger
            : count <= 5
                ? AppColors.gold
                : count <= 10
                    ? AppColors.goldLight
                    : count <= 15
                        ? AppColors.info
                        : AppColors.warning;

    // Which step pill is active (0-based)
    final int activeStep = size == null
        ? -1
        : size.isCustom
            ? 4
            : count <= 5
                ? 0
                : count <= 10
                    ? 1
                    : count <= 15
                        ? 2
                        : 3;

    const steps = ['1×1', '2×1', '3×1', '4×1.5', '5×2'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty ? AppColors.cardBorder : accent.withValues(alpha: .45),
          width: isEmpty ? 1 : 1.5,
        ),
        boxShadow: isEmpty
            ? const []
            : [BoxShadow(color: accent.withValues(alpha: .12), blurRadius: 14)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card header ──────────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.straighten_rounded,
              color: isEmpty ? AppColors.midGray : accent, size: 18),
          const SizedBox(width: 8),
          Text(
            'Acrylic Backing Size',
            style: TextStyle(
              color: isEmpty ? AppColors.midGray : AppColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          if (!isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: .4)),
              ),
              child: Text(
                '$count char${count == 1 ? '' : 's'}',
                style: TextStyle(
                    color: accent, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
        ]),
        const SizedBox(height: 12),

        // ── Empty state ──────────────────────────────────────────────────────
        if (isEmpty)
          const Center(
            child: Text(
              'Enter text above to see recommended size',
              style: TextStyle(color: AppColors.midGray, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          )

        // ── Active state ─────────────────────────────────────────────────────
        else ...[
          // Step progress bars
          Row(
              children: List.generate(steps.length, (i) {
            final active = i == activeStep;
            final done = i < activeStep;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < steps.length - 1 ? 2 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: (done || active) ? accent : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          })),
          const SizedBox(height: 6),
          // Step labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (i) {
              final active = i == activeStep;
              return Text(
                steps[i],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                  color: active ? accent : AppColors.midGray,
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Diagram + size info row
          Row(children: [
            _diagram(size!, accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recommended Size',
                        style:
                            TextStyle(color: AppColors.midGray, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      size.label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                              color: accent.withValues(alpha: .6),
                              blurRadius: 10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.currency_rupee_rounded,
                          color: AppColors.midGray, size: 13),
                      const SizedBox(width: 2),
                      const Text('Est. Price: ',
                          style: TextStyle(
                              color: AppColors.midGray, fontSize: 12)),
                      Text(
                        _price(size),
                        style: TextStyle(
                          color: size.isCustom
                              ? AppColors.warning
                              : AppColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ]),
                    Text(
                      '${size.sqft.toStringAsFixed(size.sqft == size.sqft.roundToDouble() ? 0 : 1)}'
                      ' sq ft × ₹1,500/sqft',
                      style: const TextStyle(
                          color: AppColors.midGray, fontSize: 10),
                    ),
                  ]),
            ),
          ]),

          // Custom size warning (21+ chars)
          if (size.isCustom) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: .35)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.goldDark, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Large custom size — please contact us for an exact quote.',
                    style: TextStyle(
                        color: AppColors.goldDark, fontSize: 11, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],

          // Character fill bar (denominator = 35 per requirements)
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // MUST use 35 as denominator to allow testing 21+ custom size
              value: (count / 35).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AppColors.cardBorder,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count / 35 characters', // shows X/35 as required
                style: const TextStyle(color: AppColors.midGray, fontSize: 10),
              ),
              if (count >= 30)
                const Text(
                  'Max 35 chars',
                  style: TextStyle(color: AppColors.danger, fontSize: 10),
                ),
            ],
          ),
        ],
      ]),
    );
  }
}
