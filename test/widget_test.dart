import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lpr/models/report.dart';
import 'package:lpr/widgets/empty_state.dart';
import 'package:lpr/widgets/stat_card.dart';
import 'package:lpr/widgets/status_badge.dart';

void main() {
  testWidgets('StatusBadge and SeverityBadge render properly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                StatusBadge(status: ReportStatus.inProgress),
                StatusBadge(status: ReportStatus.assigned),
                SeverityBadge(severity: ReportSeverity.critical),
                SizedBox(
                  height: 140,
                  width: 160,
                  child: StatCard(
                    label: 'Pending complaints',
                    value: '12',
                    icon: Icons.hourglass_top,
                  ),
                ),
                EmptyStateView(
                  icon: Icons.inbox,
                  title: 'No reports',
                  description: 'Everything is resolved.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text('Pending complaints'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('No reports'), findsOneWidget);
    expect(find.text('Everything is resolved.'), findsOneWidget);
  });
}
