import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import '../services/translation_service.dart';

class TranslatedText extends StatefulWidget {
  final String text;
  final String language;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const TranslatedText(
    this.text, {
    super.key,
    required this.language,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String? _translatedText;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.language != widget.language) {
      _translate();
    }
  }

  Future<void> _translate() async {
    if (widget.text.isEmpty) {
      if (mounted) setState(() => _translatedText = null);
      return;
    }

    final targetCode = TranslationService.normalizeLanguage(widget.language);
    final isTeluguSelected = targetCode == 'te';
    final isEnglishSelected = targetCode == 'en';

    // Detect language of the text
    final hasTeluguCharacters = RegExp(r'[\u0c00-\u0c7f]').hasMatch(widget.text);
    final hasEnglishCharacters = RegExp(r'[a-zA-Z]').hasMatch(widget.text);
    
    // Logic:
    // If target is Telugu ('te') and text has NO English characters -> No translate needed.
    // If target is English ('en') and text has NO Telugu characters -> No translate needed.
    
    if (isTeluguSelected && !hasEnglishCharacters) {
      if (mounted) setState(() {
        _translatedText = widget.text;
        _isTranslating = false;
      });
      return;
    }
    
    if (isEnglishSelected && !hasTeluguCharacters) {
      if (mounted) setState(() {
        _translatedText = widget.text;
        _isTranslating = false;
      });
      return;
    }

    // Proceed to translate using TranslationService
    if (mounted) setState(() => _isTranslating = true);
    
    final result = await TranslationService.translate(widget.text, to: targetCode);
    
    if (mounted) {
      setState(() {
        _translatedText = result;
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String finalText = _translatedText ?? widget.text;
    
    // If still translating and no fallback text yet, show a placeholder
    // This prevents showing the "wrong" language while fetching
    if (_isTranslating && _translatedText == null) {
      finalText = "..."; 
    }
    
    final RegExp linkRegExp = RegExp(r"((https?:\/\/|www\.)[^\s]+)");
    final Iterable<Match> matches = linkRegExp.allMatches(finalText);
    
    // Determine the style to use
    TextStyle baseStyle = widget.style ?? const TextStyle(color: Colors.black87);
    if (_isTranslating) {
      baseStyle = baseStyle.copyWith(color: baseStyle.color?.withOpacity(0.5));
    }

    // If no links, just return simple text
    if (matches.isEmpty) {
      return Text(
        finalText,
        style: baseStyle,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }

    final List<TextSpan> spans = [];
    int start = 0;

    for (final Match match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: finalText.substring(start, match.start), style: widget.style));
      }
      final String url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: widget.style?.copyWith(
            color: Colors.blueAccent,
            decoration: TextDecoration.underline,
          ) ?? const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              String urlString = url;
              if (urlString.startsWith('www.')) {
                urlString = 'https://$urlString';
              }
              final uri = Uri.parse(urlString);
              try {
                 await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint("Could not launch $uri");
              }
            },
        ),
      );
      start = match.end;
    }

    if (start < finalText.length) {
      spans.add(TextSpan(text: finalText.substring(start), style: widget.style));
    }

    return Opacity(
      opacity: _isTranslating ? 0.6 : 1.0,
      child: RichText(
        textAlign: widget.textAlign ?? TextAlign.start,
        text: TextSpan(
          children: spans,
          style: widget.style,
        ),
        maxLines: widget.maxLines,
        overflow: widget.overflow ?? (widget.maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip),
      ),
    );
  }
}
