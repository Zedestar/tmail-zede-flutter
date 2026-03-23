import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:twake_previewer_flutter/core/constants/supported_charset.dart';
import 'package:twake_previewer_flutter/core/previewer_options/options/previewer_state.dart';
import 'package:twake_previewer_flutter/core/previewer_options/previewer_options.dart';
import 'package:twake_previewer_flutter/twake_plain_text_previewer/twake_plain_text_previewer.dart';

/// Full-screen plain-text file previewer with user-overridable encoding.
///
/// Auto-detected charset is used as the initial value; the user can switch
/// between UTF-8 / Latin-1 / ASCII at any time without re-downloading.
class PlainTextPreviewDialog extends StatefulWidget {
  final String fileName;
  final Uint8List bytes;
  final SupportedCharset initialCharset;
  final VoidCallback onClose;
  final void Function(String, Uint8List) onDownload;

  const PlainTextPreviewDialog({
    super.key,
    required this.fileName,
    required this.bytes,
    required this.initialCharset,
    required this.onClose,
    required this.onDownload,
  });

  @override
  State<PlainTextPreviewDialog> createState() => _PlainTextPreviewDialogState();
}

class _PlainTextPreviewDialogState extends State<PlainTextPreviewDialog> {
  late SupportedCharset _charset;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _charset = widget.initialCharset;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
        }
      },
      child: Column(
        children: [
          _PlainTextTopBar(
            fileName: widget.fileName,
            charset: _charset,
            onCharsetChanged: (c) => setState(() => _charset = c),
            onClose: widget.onClose,
            onDownload: () => widget.onDownload(widget.fileName, widget.bytes),
          ),
          Expanded(
            child: TwakePlainTextPreviewer(
              // ValueKey forces widget rebuild (and re-decode) on charset change.
              key: ValueKey(_charset),
              supportedCharset: _charset,
              bytes: widget.bytes,
              previewerOptions: PreviewerOptions(
                previewerState: PreviewerState.success,
                width: context.width * 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlainTextTopBar extends StatelessWidget {
  final String fileName;
  final SupportedCharset charset;
  final ValueChanged<SupportedCharset> onCharsetChanged;
  final VoidCallback onClose;
  final VoidCallback onDownload;

  const _PlainTextTopBar({
    required this.fileName,
    required this.charset,
    required this.onCharsetChanged,
    required this.onClose,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 52,
      color: Colors.black.withValues(alpha: 0.3),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            padding: const EdgeInsets.all(8),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            focusColor: Colors.black.withValues(alpha: 0.3),
            hoverColor: Colors.black.withValues(alpha: 0.3),
            tooltip: appLocalizations.close,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontSize: 17,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          _EncodingSelector(charset: charset, onChanged: onCharsetChanged),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDownload,
            padding: const EdgeInsets.all(8),
            icon: const Icon(Icons.download, color: Colors.white, size: 24),
            focusColor: Colors.black.withValues(alpha: 0.3),
            hoverColor: Colors.black.withValues(alpha: 0.3),
            tooltip: appLocalizations.download,
          ),
        ],
      ),
    );
  }
}

class _EncodingSelector extends StatelessWidget {
  final SupportedCharset charset;
  final ValueChanged<SupportedCharset> onChanged;

  const _EncodingSelector({required this.charset, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<SupportedCharset>(
        value: charset,
        dropdownColor: Colors.black.withValues(alpha: 0.85),
        iconEnabledColor: Colors.white,
        items: SupportedCharset.values
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(
                  c.name.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            )
            .toList(),
        onChanged: (c) { if (c != null) onChanged(c); },
      ),
    );
  }
}
