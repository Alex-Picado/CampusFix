import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Collects a password with an explicit visibility toggle.
///
/// The owning form disposes [controller]. Values are never normalized here.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final FormFieldValidator<String> validator;
  final List<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.enabled,
    required this.validator,
    required this.autofillHints,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  final _focusNode = FocusNode();
  bool _obscured = true;

  /// Reopens text input after changing visibility without losing the selection.
  ///
  /// Closing the active connection first avoids a Flutter Web autofill bug that
  /// leaves the password input unresponsive after a visibility change and blur.
  void _toggleVisibility() {
    if (!widget.enabled) return;

    final controller = widget.controller;
    final selection = controller.selection;
    _focusNode.unfocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    if (kIsWeb) {
      // Remove stale browser autofill forms without prompting to save a value.
      TextInput.finishAutofillContext(shouldSave: false);
    }
    setState(() => _obscured = !_obscured);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled || widget.controller != controller) {
        return;
      }

      if (selection.isValid && selection.end <= controller.text.length) {
        controller.selection = selection;
      }
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    var visibilityLabel = 'Mostrar contraseña';
    var visibilityIcon = Icons.visibility_outlined;
    if (!_obscured) {
      visibilityLabel = 'Ocultar contraseña';
      visibilityIcon = Icons.visibility_off_outlined;
    }

    VoidCallback? toggleVisibility;
    if (widget.enabled) {
      toggleVisibility = _toggleVisibility;
    }

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      selectAllOnFocus: false,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: visibilityLabel,
          onPressed: toggleVisibility,
          icon: Icon(visibilityIcon),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}
