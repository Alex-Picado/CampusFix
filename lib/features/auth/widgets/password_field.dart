import 'package:flutter/material.dart';

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
  bool _obscured = true;

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
      toggleVisibility = () => setState(() => _obscured = !_obscured);
    }

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
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
}
