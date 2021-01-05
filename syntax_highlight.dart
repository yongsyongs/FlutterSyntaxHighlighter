import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef SyntaxHighlighter SyntaxHighlighterGenerator({List<dynamic> args, Map<String, dynamic> kwargs});

SyntaxHighlighterGenerator getHighlighterWithName(String languageName) {
  languageName = languageName.toLowerCase();
  SyntaxHighlighterGenerator g;
  switch(languageName) {
    case 'r': g = ({List<dynamic> args, Map<String, dynamic> kwargs}) => RSyntaxHighlighter.fromMap(args: args, kwargs: kwargs); break;
    default: g = ({List<dynamic> args, Map<String, dynamic> kwargs}) => SyntaxHighlighter.fromMap(args: args, kwargs: kwargs); break;
  }
  return g;
}

class SyntaxHighlighter {
  final String quotedStringRegExp;
  final RegExp _quotedStringRegExp;
  final String commentCharacterRegExp;
  final RegExp _commentCharacterRegExp;
  final String numberRegExp;
  final RegExp _numberRegExp;

  final List<List<String>> highlightWords;
  final List<Color> highlightColors;
  final List<TextStyle> _highlightStyles;

  final Color quotedStringColor;
  final Color commentColor;
  final Color numberColor;
  final Color defaultColor;
  final TextStyle _defaultStyle;
  final TextStyle _quotedStringStyle;
  final TextStyle _commentStyle;
  final TextStyle _numberStyle;
  TextStyle baseStyle;

  static final List<String> _defaultDelimiters = [' ', '\t'] + r', < . > / ? ; : \ | ! @ $ % ^ & * ( ) - _ = + [ ] ` ~'.split(' ');

  SyntaxHighlighter({
    this.quotedStringRegExp = r"((?<![\\])['" '"' r"])((?:.(?!(?<![\\])\1))*.?)\1",
    this.numberRegExp = r'\d+',
    this.highlightWords,
    this.highlightColors,
    this.defaultColor = Colors.black,
    this.quotedStringColor = Colors.red,
    this.commentColor = Colors.green,
    this.numberColor = Colors.blue,
    this.commentCharacterRegExp = '#.*',
    this.baseStyle,
  }) :
        assert(highlightWords != null),
        assert(highlightColors != null),
        assert(highlightWords.length == highlightColors.length),
        assert(baseStyle != null),
        _quotedStringRegExp = RegExp(quotedStringRegExp),
        _commentCharacterRegExp = RegExp(commentCharacterRegExp),
        _numberRegExp = RegExp(numberRegExp),
        _highlightStyles = highlightColors.map((e) => TextStyle(color: e, inherit: true)).toList(),
        _quotedStringStyle = TextStyle(color: quotedStringColor, inherit: true),
        _commentStyle = TextStyle(color: commentColor, inherit: true),
        _numberStyle = TextStyle(color: numberColor, inherit: true),
        _defaultStyle = TextStyle(color: defaultColor, inherit: true);

  List<TextSpan> highlight(String code) {
    List<String> tokenized = tokenizeAll(code);
    List<TextStyle> mergedStyles = _highlightStyles.map((e) => baseStyle.merge(e)).toList();
    TextStyle mergedQuotedStringStyle = baseStyle.merge(_quotedStringStyle);
    TextStyle mergedCommentStyle = baseStyle.merge(_commentStyle);
    TextStyle mergedNumberStyle = baseStyle.merge(_numberStyle);
    TextStyle mergedDefaultStyle = baseStyle.merge(_defaultStyle);

    List<TextSpan> spans = [];

    for(String token in tokenized) {
      if (token == '') continue;
      TextStyle style;
      String trimToken = token.trim();
      bool found = false;

      for(int i = 0; i < highlightWords.length; i++) {
        if (highlightWords[i].contains(trimToken)) {
          found = true;
          style = mergedStyles[i];
          break;
        }
      }
      if (!found) {
        if(trimToken.startsWith('#'))
          style = mergedCommentStyle;
        else if((trimToken.startsWith('"') && trimToken.endsWith('"')) || (trimToken.startsWith("'") && trimToken.endsWith("'")))
          style = mergedQuotedStringStyle;
        else if(_isNumeric(trimToken))
          style = mergedNumberStyle;
        else
          style = mergedDefaultStyle;
      }

      spans.add(TextSpan(text: token, style: style));
    }

    return spans;
  }

  List<String> splitKeepingDelimiter(String text, {String delimiter='\n'}) {
    List<String> splited = text.split(delimiter);
    splited = splited.asMap().entries.map((e) {
      return (e.key == splited.length - 1) ? e.value : (e.value + delimiter);
    }).toList();
    return splited;
  }

  List<String> splitLine(String text, {List<String> delimiterList}) {
    if (delimiterList == null)
      delimiterList = _defaultDelimiters;
    List<String> tokens = [];
    List<String> chars = text.split('');

    int currentIdx = 0;
    int lastIdx = 0;
    while (currentIdx < text.length) {
      if (delimiterList.contains(chars[currentIdx])) {
        String tk = text.substring(lastIdx, currentIdx);
        if (tk != '')
          tokens.add(tk);
        tokens.add(text.substring(currentIdx, currentIdx + 1));
        lastIdx = currentIdx + 1;
      }
      currentIdx++;
    }
    if (lastIdx != currentIdx)
      tokens.add(text.substring(lastIdx, currentIdx));
    return tokens;
  }

  /// input all source code
  List<String> tokenizeAll(String allText, {quotedStringRegExp}) {
    List<String> textChunks = splitNumber(null, splitComment(null, splitQuotedString(allText)));

    List<String> tokenized = [];
    for (String chunk in textChunks)
      tokenized += tokenizeLine(chunk);

    return tokenized;
  }

  List<String> splitQuotedString([String text, List<String> texts]) {
    assert(text == null || texts == null);
    if (texts == null) texts = [text];

    List<String> textChunks = [];
    for(String t in texts) {
      List<RegExpMatch> qsMatches = _quotedStringRegExp.allMatches(t).toList();
      if (qsMatches.length > 0) {
        int lastEnd = 0;
        qsMatches.forEach((element) {
          textChunks += splitKeepingDelimiter(t.substring(lastEnd, element.start));
          textChunks.add(t.substring(element.start, element.end));
          lastEnd = element.end;
        });

        if (qsMatches[qsMatches.length - 1].end < t.length)
          textChunks += splitKeepingDelimiter(t.substring(qsMatches[qsMatches.length - 1].end, t.length));
      }
      else
        textChunks += splitKeepingDelimiter(t);
    }
    return textChunks;
  }

  List<String> splitComment([String text, List<String> texts]) {
    assert(text == null || texts == null);
    if (texts == null) texts = [text];

    List<String> textChunks = [];

    for(String t in texts) {
      int tcLast = textChunks.length - 1;
      if(tcLast >= 0 && _commentCharacterRegExp.hasMatch(textChunks[tcLast])) {
        if(!textChunks[tcLast].contains('\n')) {
          textChunks[tcLast] += t;
          continue;
        }
      }
      List<RegExpMatch> cmMatches = _commentCharacterRegExp.allMatches(t).toList();
      if (cmMatches.length > 0) {
        int lastEnd = 0;
        cmMatches.forEach((element) {
          textChunks += splitKeepingDelimiter(t.substring(lastEnd, element.start));
          textChunks.add(t.substring(element.start, element.end));
          lastEnd = element.end;
        });

        if (cmMatches[cmMatches.length - 1].end < t.length)
          textChunks += splitKeepingDelimiter(t.substring(cmMatches[cmMatches.length - 1].end, t.length));
      }
      else
        textChunks += splitKeepingDelimiter(t);
    }
    return textChunks;
  }

  List<String> splitNumber([String text, List<String> texts]) {
    assert(text == null || texts == null);
    if (texts == null) texts = [text];

    List<String> textChunks = [];
    for(String t in texts) {
      if(_numberRegExp.hasMatch(t)) {
        textChunks.add(t);
        continue;
      }
      List<RegExpMatch> nbMatches = _numberRegExp.allMatches(t).toList();
      if (nbMatches.length > 0) {
        int lastEnd = 0;
        nbMatches.forEach((element) {
          textChunks += splitKeepingDelimiter(t.substring(lastEnd, element.start));
          textChunks.add(t.substring(element.start, element.end));
          lastEnd = element.end;
        });

        if (nbMatches[nbMatches.length - 1].end < t.length)
          textChunks += splitKeepingDelimiter(t.substring(nbMatches[nbMatches.length - 1].end, t.length));
      }
      else
        textChunks += splitKeepingDelimiter(t);
    }
    return textChunks;
  }


  List<String> tokenizeLine(String lineText) {
    if (lineText.startsWith('"') || lineText.startsWith("'"))
      return <String> [lineText];
    else if (_commentCharacterRegExp.hasMatch(lineText))
      return <String> [lineText];
    else
      return splitLine(lineText);
  }

  bool _isNumeric(String s) {
    if(s == null)
      return false;
    return int.tryParse(s) != null;
  }

  static SyntaxHighlighter fromMap({List<dynamic> args, Map<String, dynamic> kwargs}) {
    assert(args == null, 'SyntaxHighlighter does not need positional arguments');
    assert(kwargs != null, 'SyntaxHighlighter needs keyworded arguments.');
    var contains = kwargs.keys.contains;

    return SyntaxHighlighter(
      quotedStringRegExp: contains('quotedStringRegExp') ? kwargs['quotedStringRegExp'] : r"((?<![\\])['" '"' r"])((?:.(?!(?<![\\])\1))*.?)\1",
      highlightWords: kwargs['highlightWords'],
      highlightColors: kwargs['highlightColors'],
      quotedStringColor: contains('quotedStringColor') ? kwargs['quotedStringColor'] : Colors.red,
      defaultColor: contains('defaultColor') ? kwargs['defaultColor'] : Colors.black,
      baseStyle: kwargs['baseStyle']
    );
  }
}


class RSyntaxHighlighter extends SyntaxHighlighter {
  static final List<String> keywords = 'function if in break next repeat else for while ...'.split(' ');
  static final List<String> literals = 'NULL NA TRUE FALSE Inf NaN NA_integer_ NA_real_ NA_character_ NA_complex_'.split(' ');
  static final List<String> builtIns = ('abs acos acosh all any anyNA Arg as.call as.character ' +
    'as.complex as.double as.environment as.integer as.logical ' +
    'as.null.default as.numeric as.raw asin asinh atan atanh attr ' +
    'attributes baseenv browser c call ceiling class Conj cos cosh ' +
    'cospi cummax cummin cumprod cumsum digamma dim dimnames ' +
    'emptyenv exp expression floor forceAndCall gamma gc.time ' +
    'globalenv Im interactive invisible is.array is.atomic is.call ' +
    'is.character is.complex is.double is.environment is.expression ' +
    'is.finite is.function is.infinite is.integer is.language ' +
    'is.list is.logical is.matrix is.na is.name is.nan is.null ' +
    'is.numeric is.object is.pairlist is.raw is.recursive is.single ' +
    'is.symbol lazyLoadDBfetch length lgamma list log max min ' +
    'missing Mod names nargs nzchar oldClass on.exit pos.to.env ' +
    'proc.time prod quote range Re rep retracemem return round ' +
    'seq_along seq_len seq.int sign signif sin sinh sinpi sqrt ' +
    'standardGeneric substitute sum switch tan tanh tanpi tracemem ' +
    'trigamma trunc unclass untracemem UseMethod xtfrm').split(' ');
  RSyntaxHighlighter({TextStyle baseStyle}) : super(
    highlightWords: [keywords, literals, builtIns],
    highlightColors: [Colors.deepOrangeAccent, Colors.indigo, Colors.purple],
    baseStyle: baseStyle,
    commentCharacterRegExp: r'#(.|\s|"|' "'" ')*',
  );

  static SyntaxHighlighter fromMap({List<dynamic> args, Map<String, dynamic> kwargs}) {
    assert(args == null, 'RSyntaxHighlighter does not need positional arguments');
    assert(kwargs != null, 'RSyntaxHighlighter needs keyworded arguments.');
    return RSyntaxHighlighter(baseStyle: kwargs['baseStyle']);
  }
}