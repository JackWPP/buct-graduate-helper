import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 与网页设计稿同一套 24 线框。
const iconPaths = <String, String>{
  'bell': '<path d="M6 9a6 6 0 1 1 12 0c0 7 3 7 3 7H3s3 0 3-7"/><path d="M10 19a2 2 0 0 0 4 0"/>',
  'back': '<path d="M15 5 8 12l7 7"/>',
  'cal': '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M8 3v4M16 3v4M4 10h16"/>',
  'chart': '<path d="M4 19V5M4 19h16"/><path d="M8 16v-4M12 16V8M16 16v-6"/>',
  'check': '<circle cx="12" cy="12" r="8"/><path d="m8.5 12 2.5 2.5 4.5-5"/>',
  'star': '<path d="m12 4 2.2 4.6 5 .7-3.6 3.5.9 5.1L12 15.8 7.5 17.9l.9-5.1L4.8 9.3l5-.7Z"/>',
  'search': '<circle cx="11" cy="11" r="6"/><path d="m16 16 3 3"/>',
  'home': '<path d="M4 11.5 12 4l8 7.5"/><path d="M7 10.5V20h10v-9.5"/>',
  'grid': '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
  'user': '<circle cx="12" cy="9" r="3"/><path d="M6 19c1.5-3 3.5-4 6-4s4.5 1 6 4"/>',
  'chev': '<path d="m9 6 6 6-6 6"/>',
  'eye': '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z"/><circle cx="12" cy="12" r="2.5"/>',
  'eyeoff': '<path d="M3 3 21 21"/><path d="M10.6 6.2A10 10 0 0 1 12 6c6.5 0 10 6 10 6a18 18 0 0 1-3.1 3.7"/><path d="M6.2 6.2C3.6 8 2 12 2 12s3.5 6 10 6c1.4 0 2.7-.3 3.8-.8"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
  'book': '<path d="M5 5.5A2.5 2.5 0 0 1 7.5 3H19v16H7.5A2.5 2.5 0 0 0 5 21.5Z"/><path d="M5 5.5A2.5 2.5 0 0 1 7.5 8H19"/>',
  'file': '<path d="M7 3h7l5 5v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"/><path d="M14 3v6h6"/>',
  'swap': '<path d="M7 7h11l-3-3"/><path d="M17 17H6l3 3"/>',
  'clipboard': '<rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4.5h6V4a2 2 0 0 0-2-2h-2a2 2 0 0 0-2 2v.5Z"/>',
  'flag': '<path d="M6 21V4"/><path d="M6 5h11l-2.2 3.5L17 12H6"/>',
  'briefcase': '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5.5A1.5 1.5 0 0 1 9.5 4h5A1.5 1.5 0 0 1 16 5.5V7M3 12h18"/>',
  'award': '<circle cx="12" cy="9" r="5"/><path d="m8.5 13.2-1.2 6.8L12 17.2l4.7 2.8-1.2-6.8"/>',
  'monitor': '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
  'wallet': '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18"/><path d="M16 14h.01"/>',
  'shield': '<path d="M12 3 5 6v6c0 4.2 2.8 6.4 7 8 4.2-1.6 7-3.8 7-8V6Z"/>',
  'pencil': '<path d="M4 20h4L19 9l-4-4L4 16v4Z"/><path d="m13 7 4 4"/>',
  'clock': '<circle cx="12" cy="12" r="8"/><path d="M12 8v5l3 2"/>',
  'folder': '<path d="M3 7.5A2 2 0 0 1 5 5.5h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>',
  'cpu': '<rect x="7" y="7" width="10" height="10" rx="2"/><path d="M9 3v4M15 3v4M9 17v4M15 17v4M3 9h4M3 15h4M17 9h4M17 15h4"/>',
};

const serviceGlyphs = <String, String>{
  'grjbxx': 'user',
  'xyjc': 'swap',
  'xsxqzc': 'check',
  'xsrxdj': 'user',
  'xslqfc': 'check',
  'grxxxg': 'pencil',
  'ccqjwh': 'swap',
  'xjydsq': 'swap',
  'djksbm': 'clipboard',
  'djkscj': 'chart',
  'zpxxhd': 'user',
  'pyfacx': 'book',
  'pyjhtj': 'file',
  'pyjhcx': 'file',
  'kcmxsq': 'file',
  'xswsxk': 'grid',
  'xswsxk_kb': 'check',
  'xkjgcx': 'check',
  'xskbcx': 'cal',
  'ttkcx': 'swap',
  'kckccx': 'clipboard',
  'xscjcx': 'chart',
  'qxkczml': 'book',
  'cxhkbksq': 'file',
  'wsjxpj': 'star',
  'gjxsjlhd': 'flag',
  'py_zysjwc': 'briefcase',
  'xnjddj': 'file',
  'pypgsq': 'award',
  'knzzsq': 'wallet',
  'szgwsq': 'briefcase',
  'xshdbm': 'flag',
  'xwsxsq': 'briefcase',
  'zyzfwbm': 'user',
  'tyydbm': 'check',
  'tyydmxsq': 'file',
  'xsfblwdj': 'file',
  'xskycgdj': 'folder',
  'xszlcgdj': 'cpu',
  'xshjcgdj': 'award',
  'ktlwsq': 'flag',
  'lwktsq': 'file',
  'zqkhsq': 'clipboard',
  'zqkhdj': 'file',
  'xsdbsq': 'shield',
  'lwpygl': 'file',
  'xsxwsq': 'award',
  'wskscp': 'pencil',
};

String serviceGlyph(String id) => serviceGlyphs[id] ?? 'file';

class HuayanIcon extends StatelessWidget {
  const HuayanIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = const Color(0xFF14171F),
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final body = iconPaths[name] ?? iconPaths['file']!;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">$body</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
      excludeFromSemantics: true,
    );
  }
}

class HuayanChevron extends StatelessWidget {
  const HuayanChevron({super.key, this.color = const Color(0xFFB6BCC9)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return HuayanIcon('chev', size: 18, color: color);
  }
}
