import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cycle_avatar/main.dart';

void main() {
  testWidgets('CycleAvatar app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: CycleAvatarApp()));

    // Verify that the app starts and shows the welcome message.
    expect(find.text('Welcome to CycleAvatar'), findsOneWidget);
    expect(find.text('Your smart fitness companion'), findsOneWidget);
  });
}