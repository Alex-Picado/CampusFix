import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/auth/widgets/password_field.dart';

const _passwordKey = ValueKey('password-under-test');
const _otherFieldKey = ValueKey('other-field');

void main() {
  final variants = <String, List<String>>{
    'sign-in password': const [AutofillHints.password],
    'registration password': const [AutofillHints.newPassword],
    'password confirmation': const [],
  };

  for (final variant in variants.entries) {
    testWidgets('${variant.key} accepts incremental typing and corrections', (
      tester,
    ) async {
      final controller = await _mount(tester, hints: variant.value);
      await _focusPassword(tester);

      // Keep the original input connection throughout the edit sequence.
      for (var length = 1; length <= 6; length++) {
        await _edit(tester, '123122'.substring(0, length));
        expect(controller.text, '123122'.substring(0, length));
      }

      await tester.pump(const Duration(seconds: 1));
      await _edit(tester, '12312');
      expect(controller.text, '12312');
      await _edit(tester, '123123');
      expect(controller.text, '123123');

      // Replace a selection in the middle, rather than replacing the field.
      await _edit(
        tester,
        '123123',
        selection: const TextSelection(baseOffset: 2, extentOffset: 4),
      );
      await _edit(
        tester,
        '129923',
        selection: const TextSelection.collapsed(offset: 4),
      );
      expect(controller.text, '129923');
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
      expect(_editable(tester).focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'visibility changes preserve selection and subsequent editing',
    (tester) async {
      final controller = await _mount(tester);
      await _focusPassword(tester);

      for (var round = 0; round < 4; round++) {
        const selection = TextSelection(baseOffset: 3, extentOffset: 6);
        await _edit(tester, '123122', selection: selection);
        final wasObscured = _editable(tester).obscureText;
        final toggle = wasObscured
            ? 'Mostrar contraseña'
            : 'Ocultar contraseña';

        await tester.tap(find.byTooltip(toggle));
        await tester.pumpAndSettle();

        expect(_editable(tester).obscureText, !wasObscured);
        expect(controller.text, '123122');
        expect(controller.selection, selection);
        expect(_editable(tester).focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        await _edit(tester, '123123');
        expect(controller.text, '123123');

        await tester.tap(find.byKey(_otherFieldKey));
        await tester.pump();
        expect(_editable(tester).focusNode.hasFocus, isFalse);
        await _focusPassword(tester);

        await _edit(tester, '12312');
        expect(controller.text, '12312');
        await _edit(tester, '123123');
        expect(controller.text, '123123');
      }

      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );

  testWidgets('password edits preserve leading, internal and trailing spaces', (
    tester,
  ) async {
    final controller = await _mount(tester);
    await _focusPassword(tester);

    await _edit(tester, ' 123 122 ');
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pumpAndSettle();
    expect(controller.text, ' 123 122 ');

    await _edit(tester, ' 123 123 ');
    expect(controller.text, ' 123 123 ');
    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pumpAndSettle();
    expect(controller.text, ' 123 123 ');
    expect(_editable(tester).focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled password cannot receive focus or change visibility', (
    tester,
  ) async {
    final controller = await _mount(tester, enabled: false);
    controller.text = 'unchanged-password';
    await tester.pump();

    await tester.tap(find.byKey(_passwordKey), warnIfMissed: false);
    await tester.pump();
    final toggle = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(_passwordKey),
        matching: find.byType(IconButton),
      ),
    );

    expect(toggle.onPressed, isNull);
    expect(_editable(tester).focusNode.hasFocus, isFalse);
    expect(_editable(tester).obscureText, isTrue);
    expect(controller.text, 'unchanged-password');
    expect(tester.takeException(), isNull);
  });
}

Future<TextEditingController> _mount(
  WidgetTester tester, {
  List<String> hints = const [AutofillHints.password],
  bool enabled = true,
}) async {
  final controller = TextEditingController();
  // Unmount fields before disposing the externally owned controller.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AutofillGroup(
          child: Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                PasswordField(
                  key: _passwordKey,
                  controller: controller,
                  label: 'Contraseña',
                  enabled: enabled,
                  validator: (_) => null,
                  autofillHints: hints,
                ),
                TextFormField(
                  key: _otherFieldKey,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

EditableText _editable(WidgetTester tester) {
  return tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(_passwordKey),
      matching: find.byType(EditableText),
    ),
  );
}

Future<void> _focusPassword(WidgetTester tester) async {
  await tester.tap(find.byKey(_passwordKey));
  await tester.pump();
  expect(_editable(tester).focusNode.hasFocus, isTrue);
  expect(tester.testTextInput.hasAnyClients, isTrue);
}

Future<void> _edit(
  WidgetTester tester,
  String text, {
  TextSelection? selection,
}) async {
  // Simulate edits from the already focused platform connection. enterText
  // would request the keyboard again and could conceal a lost connection.
  expect(tester.testTextInput.hasAnyClients, isTrue);
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: selection ?? TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
}
