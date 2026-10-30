// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Every fenced `dart` code block in the repository's Markdown files parses
/// and passes static type and API analysis under `package:markdown_analyze`.
///
/// Why this matters:
/// - Agents and contributors copy code from `.agents/skills/`, `README.md`,
///   and `documentation/` directly into production code and tests. A syntax
///   error or a drifted class/method signature in a Markdown code block
///   causes agents following the skill to write broken code.
///
/// `third_party/` is vendored and excluded by default in
/// [MarkdownAnalyzeConfig.excludedPathSegments]. Revisit this check if
/// Markdown code block validation moves into a built-in `skills_lint` CLI
/// rule that CI runs over the repository.
library;

import 'dart:io';

import 'package:markdown_analyze/markdown_analyze.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'src/repo_paths.dart';

const List<String> _ambientImports = [
  "import 'dart:async';",
  "import 'dart:io';",
  "import 'dart:math' as math;",
  "import 'package:path/path.dart' as p;",
  "import 'package:path/path.dart' as path;",
  "import 'package:skills_lint/skills_lint.dart';",
  "import 'package:test/test.dart';",
];

const String _fix =
    'Fix the syntax, type, or API error in the fenced ```dart block, or mark an '
    'intentional compile-error example with an inline `// Error:` comment.';

void main() {
  final String fallbackConfigPath = p.join(repoRoot, '.dart_tool', 'package_config.json');
  final analyzer = MarkdownDartAnalyzer(
    config: MarkdownAnalyzeConfig(
      ambientImports: _ambientImports,
      fallbackPackageConfigPath: fallbackConfigPath,
    ),
  );

  test('every Markdown Dart code block in the repository passes static analysis', () async {
    final MarkdownAnalysisResult result = await analyzer.analyzeDirectory(
      contextRoot: packageRoot,
      markdownRoot: repoRoot,
    );
    final List<String> descriptions = [
      for (final MarkdownDiagnostic d in result.diagnostics) d.describe(),
    ];
    expect(
      descriptions,
      isEmpty,
      reason: '${descriptions.length} violation(s):\n${descriptions.join('\n')}\n\nFix: $_fix',
    );
  });

  test('detector reports broken Dart blocks and passes valid ones', () async {
    final Directory tempDir = Directory.systemTemp.createTempSync('md_convention_test_');
    try {
      final mdFile = File(p.join(tempDir.path, 'SKILL.md'))
        ..writeAsStringSync('''
```dart
int add(int a, int b) => a + b;
```

```dart
int broken() => 'not an int';
```
''');
      final MarkdownAnalysisResult result = await analyzer.analyzeFiles(
        contextRoot: packageRoot,
        markdownRoot: tempDir.path,
        markdownFiles: [mdFile],
      );
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.block.location, 'SKILL.md:6-6');
      expect(result.diagnostics.single.code, 'return_of_invalid_type');
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
