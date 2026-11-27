import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a single styled text span
// ─────────────────────────────────────────────────────────────────────────────
class _Run {
  String text;
  bool bold;
  bool italic;
  bool underline;
  bool strike;

  _Run({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });

  _Run clone({String? text}) => _Run(
        text: text ?? this.text,
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
      );

  bool sameStyle(_Run other) =>
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline &&
      strike == other.strike;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rich TextEditingController
// Does NOT override the `text` getter — Flutter manages value.text normally.
// We keep a separate `_runs` list that always mirrors value.text in length.
// ─────────────────────────────────────────────────────────────────────────────
class _RichController extends TextEditingController {
  final List<_Run> _runs;
  String _lastText; // text at the time of last sync

  _RichController(String initialHtml)
      : _runs = _parseHtmlIterative(initialHtml),
        _lastText =
            _parseHtmlIterative(initialHtml).map((r) => r.text).join(),
        super(
          text: _parseHtmlIterative(initialHtml).map((r) => r.text).join(),
        );

  // ── Expose plain text from runs (mirrors value.text) ────────────────────
  String get plainText => _runs.map((r) => r.text).join();

  // ── Called from onChanged — diffs old vs new and updates runs ───────────
  void syncFromTextField(String newText) {
    final oldText = _lastText;
    if (newText == oldText) return;

    // Find the contiguous changed region
    int prefixLen = 0;
    while (prefixLen < oldText.length &&
        prefixLen < newText.length &&
        oldText[prefixLen] == newText[prefixLen]) {
      prefixLen++;
    }

    int oldSuffix = oldText.length;
    int newSuffix = newText.length;
    while (oldSuffix > prefixLen &&
        newSuffix > prefixLen &&
        oldText[oldSuffix - 1] == newText[newSuffix - 1]) {
      oldSuffix--;
      newSuffix--;
    }

    final deletedLen = oldSuffix - prefixLen;
    final insertedText = newText.substring(prefixLen, newSuffix);

    if (deletedLen > 0) _deleteRange(prefixLen, prefixLen + deletedLen);
    if (insertedText.isNotEmpty) _insertAt(prefixLen, insertedText);

    _merge();
    _lastText = newText;
    value = value.copyWith();
  }

  // ── Insert text at a cursor position (inherits style of prior char) ──────
  void insertText(int offset, String inserted) {
    _insertAt(offset, inserted);
    _merge();
    _lastText = plainText;
    value = value.copyWith();
  }

  // ── Toggle bold/italic/underline/strike on a range ───────────────────────
  void toggleFormat(int start, int end, String format) {
    if (start >= end) return;
    _splitAt(start);
    _splitAt(end);

    // Check if ALL runs in range already have this format
    int cursor = 0;
    bool allHave = true;
    for (final r in _runs) {
      final runEnd = cursor + r.text.length;
      if (cursor >= start && runEnd <= end) {
        switch (format) {
          case 'bold':
            if (!r.bold) allHave = false;
          case 'italic':
            if (!r.italic) allHave = false;
          case 'underline':
            if (!r.underline) allHave = false;
          case 'strike':
            if (!r.strike) allHave = false;
        }
      }
      cursor = runEnd;
    }

    // Apply opposite
    cursor = 0;
    for (final r in _runs) {
      final runEnd = cursor + r.text.length;
      if (cursor >= start && runEnd <= end) {
        switch (format) {
          case 'bold':
            r.bold = !allHave;
          case 'italic':
            r.italic = !allHave;
          case 'underline':
            r.underline = !allHave;
          case 'strike':
            r.strike = !allHave;
        }
      }
      cursor = runEnd;
    }

    _merge();
    value = value.copyWith();
  }

  // ── Check if ALL selected runs have a format ─────────────────────────────
  bool selectionHas(int start, int end, String format) {
    if (start >= end) return false;
    _splitAt(start);
    _splitAt(end);
    int cursor = 0;
    for (final r in _runs) {
      final runEnd = cursor + r.text.length;
      if (cursor >= start && runEnd <= end) {
        switch (format) {
          case 'bold':
            if (!r.bold) return false;
          case 'italic':
            if (!r.italic) return false;
          case 'underline':
            if (!r.underline) return false;
          case 'strike':
            if (!r.strike) return false;
        }
      }
      cursor = runEnd;
    }
    return true;
  }

  // ── Serialize to HTML ─────────────────────────────────────────────────────
  String toHtml() {
    final sb = StringBuffer();
    for (final r in _runs) {
      String t = r.text
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('\n', '<br>');
      if (r.bold) t = '<b>$t</b>';
      if (r.italic) t = '<i>$t</i>';
      if (r.underline) t = '<u>$t</u>';
      if (r.strike) t = '<s>$t</s>';
      sb.write(t);
    }
    return sb.toString();
  }

  // ── Build TextSpan for rendering ─────────────────────────────────────────
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (_runs.isEmpty) return TextSpan(style: base, text: '');
    return TextSpan(
      style: base,
      children: _runs.map((r) {
        final decs = <TextDecoration>[];
        if (r.underline) decs.add(TextDecoration.underline);
        if (r.strike) decs.add(TextDecoration.lineThrough);
        final dec = decs.isEmpty
            ? TextDecoration.none
            : TextDecoration.combine(decs);
        return TextSpan(
          text: r.text,
          style: base.copyWith(
            fontWeight: r.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
            decoration: dec,
          ),
        );
      }).toList(),
    );
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  void _splitAt(int offset) {
    if (offset <= 0 || offset >= plainText.length) return;
    int cursor = 0;
    for (int i = 0; i < _runs.length; i++) {
      final runEnd = cursor + _runs[i].text.length;
      if (cursor < offset && offset < runEnd) {
        final r = _runs[i];
        final left = r.clone(text: r.text.substring(0, offset - cursor));
        final right = r.clone(text: r.text.substring(offset - cursor));
        _runs.replaceRange(i, i + 1, [left, right]);
        return;
      }
      cursor = runEnd;
    }
  }

  void _deleteRange(int start, int end) {
    _splitAt(start);
    _splitAt(end);
    int cursor = 0;
    _runs.removeWhere((r) {
      final runEnd = cursor + r.text.length;
      final remove = cursor >= start && runEnd <= end;
      cursor = runEnd;
      return remove;
    });
    if (_runs.isEmpty) _runs.add(_Run(text: ''));
  }

  void _insertAt(int offset, String text) {
    if (_runs.isEmpty) {
      _runs.add(_Run(text: text));
      return;
    }
    _splitAt(offset);
    int cursor = 0;
    for (int i = 0; i < _runs.length; i++) {
      final runEnd = cursor + _runs[i].text.length;
      if (cursor == offset) {
        // Inherit style from the run before insertion point
        final style = i > 0 ? _runs[i - 1] : _runs[i];
        _runs.insert(i, style.clone(text: text));
        return;
      }
      if (cursor < offset && offset <= runEnd && i == _runs.length - 1) {
        _runs[i].text += text;
        return;
      }
      cursor = runEnd;
    }
    _runs.last.text += text;
  }

  void _merge() {
    for (int i = _runs.length - 1; i > 0; i--) {
      if (_runs[i - 1].sameStyle(_runs[i])) {
        _runs[i - 1].text += _runs[i].text;
        _runs.removeAt(i);
      }
    }
    if (_runs.isEmpty) _runs.add(_Run(text: ''));
  }

  // ── HTML parser ───────────────────────────────────────────────────────────
  static List<_Run> _parseHtmlIterative(String html) {
    if (html.isEmpty) return [_Run(text: '')];
    final runs = <_Run>[];
    final stack = <Map<String, bool>>[
      {'bold': false, 'italic': false, 'underline': false, 'strike': false}
    ];
    final tokenRe = RegExp(r'(<[^>]+>|[^<]+)', caseSensitive: false);
    for (final m in tokenRe.allMatches(html)) {
      final token = m.group(0)!;
      if (token.startsWith('<')) {
        final tm =
            RegExp(r'<(/?)(\w+)', caseSensitive: false).firstMatch(token);
        if (tm == null) continue;
        final closing = tm.group(1) == '/';
        final tag = tm.group(2)!.toLowerCase();
        if (!closing) {
          final cur = Map<String, bool>.from(stack.last);
          switch (tag) {
            case 'b':
            case 'strong':
              cur['bold'] = true;
            case 'i':
            case 'em':
              cur['italic'] = true;
            case 'u':
              cur['underline'] = true;
            case 's':
            case 'del':
            case 'strike':
              cur['strike'] = true;
            case 'br':
              runs.add(_Run(
                text: '\n',
                bold: stack.last['bold']!,
                italic: stack.last['italic']!,
                underline: stack.last['underline']!,
                strike: stack.last['strike']!,
              ));
              continue;
          }
          stack.add(cur);
        } else {
          if (stack.length > 1) stack.removeLast();
        }
      } else {
        final t = token
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&nbsp;', ' ');
        if (t.isEmpty) continue;
        final s = stack.last;
        runs.add(_Run(
          text: t,
          bold: s['bold']!,
          italic: s['italic']!,
          underline: s['underline']!,
          strike: s['strike']!,
        ));
      }
    }
    if (runs.isEmpty) runs.add(_Run(text: ''));
    return runs;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public Widget
// ─────────────────────────────────────────────────────────────────────────────
class RichTextEditorWidget extends StatefulWidget {
  final TextEditingController controller; // stores HTML
  final String? hint;

  const RichTextEditorWidget({
    super.key,
    required this.controller,
    this.hint,
  });

  @override
  State<RichTextEditorWidget> createState() => _RichTextEditorWidgetState();
}

class _RichTextEditorWidgetState extends State<RichTextEditorWidget> {
  late _RichController _rich;
  late FocusNode _focusNode;

  bool _selBold = false;
  bool _selItalic = false;
  bool _selUnderline = false;
  bool _selStrike = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _rich = _RichController(widget.controller.text);
    // Push HTML to parent whenever runs change
    _rich.addListener(_onChanged);
  }

  void _onChanged() {
    final html = _rich.toHtml();
    if (widget.controller.text != html) {
      widget.controller.text = html;
    }
  }

  void _updateToolbarState() {
    final sel = _rich.selection;
    if (!sel.isValid || sel.isCollapsed) {
      setState(() {
        _selBold = false;
        _selItalic = false;
        _selUnderline = false;
        _selStrike = false;
      });
      return;
    }
    setState(() {
      _selBold = _rich.selectionHas(sel.start, sel.end, 'bold');
      _selItalic = _rich.selectionHas(sel.start, sel.end, 'italic');
      _selUnderline = _rich.selectionHas(sel.start, sel.end, 'underline');
      _selStrike = _rich.selectionHas(sel.start, sel.end, 'strike');
    });
  }

  void _applyFormat(String format) {
    final sel = _rich.selection;
    if (!sel.isValid || sel.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select text first, then tap the format button.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),

      );
      return;
    }
    final start = sel.start;
    final end = sel.end;
    _rich.toggleFormat(start, end, format);
    // Restore selection after mutation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rich.selection = TextSelection(baseOffset: start, extentOffset: end);
      _updateToolbarState();
    });
  }

  void _insertBullet() {
    final sel = _rich.selection;
    final pos = sel.isValid ? sel.end : _rich.plainText.length;
    _rich.insertText(pos, '\n• ');
    // Sync Flutter's internal value
    _rich.value = TextEditingValue(
      text: _rich.plainText,
      selection: TextSelection.collapsed(offset: pos + 3),
    );
    _rich._lastText = _rich.plainText;
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _rich.removeListener(_onChanged);
    _rich.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'About / Biography',
          style: AppFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4A4E5C),
          ),
        ),
        const SizedBox(height: 8),

        // ── Toolbar ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              _Btn(
                icon: Icons.format_bold,
                label: 'Bold',
                active: _selBold,
                onTap: () => _applyFormat('bold'),
              ),
              _Btn(
                icon: Icons.format_italic,
                label: 'Italic',
                active: _selItalic,
                onTap: () => _applyFormat('italic'),
              ),
              _Btn(
                icon: Icons.format_underline,
                label: 'Underline',
                active: _selUnderline,
                onTap: () => _applyFormat('underline'),
              ),
              _Btn(
                icon: Icons.format_strikethrough,
                label: 'Strikethrough',
                active: _selStrike,
                onTap: () => _applyFormat('strike'),
              ),
              Container(
                  width: 1,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey.shade300),
              _Btn(
                icon: Icons.format_list_bulleted,
                label: 'Bullet',
                active: false,
                onTap: _insertBullet,
              ),
            ],
          ),
        ),

        // ── Editor ───────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border(
              left: BorderSide(color: Colors.grey.shade200),
              right: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: TextField(
            controller: _rich,
            focusNode: _focusNode,
            maxLines: 8,
            minLines: 5,
            style: AppFonts.poppins(
              color: const Color(0xFF1A1A1A),
              fontSize: 14,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: widget.hint ??
                  'Type here. Select text, then tap Bold/Italic…',
              hintStyle:
                  AppFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
            onChanged: (val) {
              _rich.syncFromTextField(val);
            },
            onTap: _updateToolbarState,
          ),
        ),

        const SizedBox(height: 6),
        Text(
          '✏️  Select a word or phrase, then tap a format button above.',
          style: AppFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar button
// ─────────────────────────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Btn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFEC4444).withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? const Color(0xFFEC4444) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
