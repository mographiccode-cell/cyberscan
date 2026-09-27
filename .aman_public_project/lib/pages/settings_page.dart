import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _prefs = PreferencesService();
  bool _history = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await _prefs.historyEnabled();
    if (mounted) setState(() => _history = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Local‑first'),
            subtitle: Text('لا يوجد حساب ولا تحليلات ولا رفع سحابي. التشغيل الأساسي محلي على الجهاز.'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.history_rounded),
            title: const Text('حفظ سجل التشغيل'),
            subtitle: const Text('يمكن تعطيله للحصول على وضع خاص مشابه لـNOVA.'),
            value: _history,
            onChanged: (value) async {
              await _prefs.setHistoryEnabled(value);
              if (!value) await _prefs.clearRecent();
              if (mounted) setState(() => _history = value);
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.speed_rounded),
            title: Text('محرك التشغيل'),
            subtitle: Text('media_kit/libmpv مع تسريع عتادي ودعم واسع للصيغ والترجمات.'),
          ),
          const ListTile(
            leading: Icon(Icons.gesture_rounded),
            title: Text('الإيماءات'),
            subtitle: Text('سحب أفقي للتقديم، يسار للسطوع، يمين للصوت، نقر مزدوج ±10 ثوانٍ، وقرص للتكبير.'),
          ),
          const ListTile(
            leading: Icon(Icons.subtitles_outlined),
            title: Text('الترجمة والصوت'),
            subtitle: Text('اختيار المسارات المضمنة وإضافة ملفات ترجمة خارجية.'),
          ),
          const Divider(),
          const ListTile(
            title: Text('أمان بلاير 0.1.0'),
            subtitle: Text('تصميم وبرمجة م.محمود دغَبس • 74813824'),
          ),
        ],
      ),
    );
  }
}
