// SentinelX - SectionHeader Layout Contract Verification Test
// Verifies that SectionHeader never throws RenderFlex unbounded width assertions,
// whether placed in bounded containers or unconstrained horizontal flex containers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel_x/shared/widgets/sentinel_widgets.dart';

void main() {
  testWidgets('SectionHeader renders without assertions in bounded container', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SectionHeader(
              title: 'Threat Timeline',
              icon: Icons.timeline_outlined,
              trailing: Text('Live'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Threat Timeline'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
  });

  testWidgets('SectionHeader renders without RenderFlex unbounded error inside an unconstrained Row', (tester) async {
    // Placing SectionHeader inside a Row gives it BoxConstraints(0 <= w <= Infinity)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SectionHeader(
                title: 'Live Audio Waveform',
                icon: Icons.graphic_eq_rounded,
                trailing: Text('85 dBFS'),
              ),
            ],
          ),
        ),
      ),
    );

    // Prior to fix, this threw: RenderFlex children have non-zero flex but incoming width constraints are unbounded.
    expect(tester.takeException(), isNull);
    expect(find.text('Live Audio Waveform'), findsOneWidget);
    expect(find.text('85 dBFS'), findsOneWidget);
  });

  testWidgets('SectionHeader handles long title without horizontal overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 250,
            child: SectionHeader(
              title: 'Very Long Surveillance Incident Header Text That Might Cause Overflow',
              icon: Icons.warning_amber_rounded,
              trailing: Text('Urgent'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Urgent'), findsOneWidget);
  });
}
