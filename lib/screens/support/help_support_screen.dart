import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.navy,
          surfaceTintColor: Colors.transparent,
          title: const Text('Help & Support',
              style: TextStyle(
                  color: AppColors.navy, fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.goldDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.gold, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('SignFix Support',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('We\'re here to help you 24/7',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ])),
              ]),
            ),
            const SizedBox(height: 20),

            // Contact options
            const _SectionTitle('Contact Us'),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.phone_rounded,
              color: AppColors.goldDark,
              title: 'Call Us',
              subtitle: '+91 98765 43210',
              onTap: () => _launch('tel:+919876543210'),
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.chat_rounded,
              color: AppColors.goldDark,
              title: 'WhatsApp',
              subtitle: 'Chat with our support team',
              onTap: () =>
                  _launch('https://wa.me/919876543210?text=Hi SignFix Support'),
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.email_rounded,
              color: AppColors.navy,
              title: 'Email',
              subtitle: 'support@signfix.in',
              onTap: () => _launch('mailto:support@signfix.in'),
            ),
            const SizedBox(height: 24),

            // FAQs
            const _SectionTitle('Frequently Asked Questions'),
            const SizedBox(height: 10),
            ...[
              (
                'How do I place a new sign board order?',
                'Go to the Order tab, select your sign type, enter dimensions and material, get an instant estimate, then submit your order.'
              ),
              (
                'How long does delivery take?',
                'Standard orders take 5–7 working days after confirmation. Express orders can be completed in 3–4 days.'
              ),
              (
                'How do I track my order?',
                'Go to the Track tab to see real-time status of all your orders and service requests.'
              ),
              (
                'How do I request a service/repair?',
                'Go to the Service tab, take a photo, select the problem category, share your GPS location and submit.'
              ),
              (
                'What payment methods are accepted?',
                'We accept UPI (GPay, PhonePe, Paytm), Credit/Debit Cards, Net Banking, and EMI options through Razorpay.'
              ),
              (
                'How do I cancel an order?',
                'Orders can be cancelled within 24 hours of placement. Contact our support team via WhatsApp or call.'
              ),
              (
                'What is the warranty on sign boards?',
                'We offer a 6-month warranty on LED modules and 1-year structural warranty on all sign boards.'
              ),
            ].map((faq) => _FaqItem(question: faq.$1, answer: faq.$2)),

            const SizedBox(height: 24),

            // Business hours
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.access_time_rounded,
                          color: AppColors.gold, size: 18),
                      SizedBox(width: 8),
                      Text('Business Hours',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ]),
                    SizedBox(height: 12),
                    _HoursRow('Monday – Saturday', '9:00 AM – 7:00 PM'),
                    _HoursRow('Sunday', '10:00 AM – 4:00 PM'),
                    _HoursRow('Emergency Service', '24/7 Available'),
                  ]),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w800));
}

class _ContactCard extends StatelessWidget {
  const _ContactCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ]),
        ),
      );
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});
  final String question, answer;
  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: AppColors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _open
                  ? AppColors.gold.withValues(alpha: .4)
                  : AppColors.cardBorder,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              onExpansionChanged: (v) => setState(() => _open = v),
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: Icon(Icons.help_outline_rounded,
                  color: _open ? AppColors.goldDark : AppColors.midGray,
                  size: 20),
              title: Text(widget.question,
                  style: TextStyle(
                    color: _open ? AppColors.goldDark : AppColors.navy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  )),
              trailing: Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.goldDark,
                  size: 22),
              children: [
                Text(widget.answer,
                    style: const TextStyle(
                        color: AppColors.textBody, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ),
      );
}

class _HoursRow extends StatelessWidget {
  const _HoursRow(this.day, this.time);
  final String day, time;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(day,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12))),
          Text(time,
              style: const TextStyle(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ]),
      );
}
