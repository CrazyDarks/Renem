import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/supported_languages.dart';

/// Reusable searchable modal sheet for selecting any of the 92 supported languages.
class LanguagePickerSheet extends StatefulWidget {
  const LanguagePickerSheet({
    super.key,
    required this.title,
    required this.currentCode,
  });

  final String title;
  final String currentCode;

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = supportedLanguages.where((lang) {
      if (query.isEmpty) return true;
      return lang.nameUk.toLowerCase().contains(query) ||
          lang.englishName.toLowerCase().contains(query) ||
          lang.nativeName.toLowerCase().contains(query) ||
          lang.code.toLowerCase().contains(query);
    }).toList();

    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = (mediaQuery.size.height * 0.76).clamp(320.0, 680.0);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.title} (${supportedLanguages.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: s.tr('search_vocab_hint'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, idx) {
                  final lang = filtered[idx];
                  final isSelected = lang.code == widget.currentCode;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    selected: isSelected,
                    leading: Text(
                      lang.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      lang.displayNativeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${lang.nameUk} • ${lang.englishName} (${lang.code})',
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      FocusScope.of(ctx).unfocus();
                      Navigator.of(ctx).pop(lang.code);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
