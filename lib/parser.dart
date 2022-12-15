import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart' as xml show parseEvents;

import 'src/svg/parser_state.dart';
import 'src/svg/theme.dart';
import 'src/vector_drawable.dart';

/// Parses SVG data into a [DrawableRoot].
class SvgParser {
  /// Parses SVG from a string to a [DrawableRoot] with the provided [theme].
  ///
  /// The [key] parameter is used for debugging purposes.
  ///
  /// By default SVG parsing will only log warnings when detecting unsupported
  /// elements in an SVG.
  /// If [warningsAsErrors] is true the function will throw with an error
  /// instead.
  /// You might want to set this to true for test and to false at runtime.
  /// Defaults to false.
  Future<DrawableRoot> parse(
    String str, {
    SvgTheme theme = const SvgTheme(),
    String? key,
    bool warningsAsErrors = false,
  }) async {
    final String fixedSvg = await _fixDefsOrder(str);
    final SvgParserState state =
        SvgParserState(xml.parseEvents(fixedSvg), theme, key, warningsAsErrors);
    return await state.parse();
  }

  Future<String> _fixDefsOrder(String rawXml) async {
    //issue: https://github.com/dnfield/flutter_svg/issues/102
    //source: https://github.com/Tokenyet/flutter_svg_opt

    final XmlDocument doc = XmlDocument.parse(rawXml);
    final XmlElement? svgDoc = doc.firstElementChild;

    if (svgDoc == null) {
      return rawXml;
    }

    XmlElement? defsElement;
    final List<XmlElement> notDefsElements = <XmlElement>[];

    for (final XmlElement element in svgDoc.childElements) {
      if (element.name.qualified.toLowerCase() == 'defs') {
        defsElement = element;
      } else {
        notDefsElements.add(element);
      }
    }
    if (defsElement == null) {
      return rawXml;
    }

    final XmlBuilder builder = XmlBuilder();
    builder.element(
      'svg',
      attributes: Map<String, String>.fromEntries(
        svgDoc.attributes.map(
          (XmlAttribute e) =>
              MapEntry<String, String>(e.name.qualified, e.value),
        ),
      ),
      nest: () {
        builder.xml(defsElement!.outerXml);
        for (final XmlElement sibling in notDefsElements) {
          builder.xml(sibling.outerXml);
        }
      },
    );

    final String output = builder.buildDocument().toXmlString();

    return output;
  }
}
