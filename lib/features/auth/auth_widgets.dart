import 'package:flutter/material.dart';

/// Shared look of the login and register screens: the app's background
/// picture with a dark veil, and in the middle a white rounded card
/// (like the app's dialogs) that holds the title, the fields and the
/// buttons. The card moves up and scrolls when the keyboard appears.

/// The blue used for typed text and labels, as in the dialogs.
const Color authBlue = Colors.blue;

/// Background picture + veil + a centred white card with [children].
/// [topLeft] (e.g. a back button) is placed in the top-left corner of
/// the card.
class AuthBackground extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? topLeft;

  const AuthBackground({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/cellnotation_background.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.45)),
        ),

        // LayoutBuilder + a min-height ConstrainedBox centres the card
        // when it is shorter than the screen and still lets it scroll
        // when the keyboard leaves too little room.
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints:
                BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Material(
                        color: Colors.white,
                        elevation: 12,
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
                          child: Stack(
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 28),
                                  ...children,
                                ],
                              ),
                              if (topLeft != null)
                                Positioned(left: 0, top: 0, child: topLeft!),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A framed, rounded field with an icon, blue text and a clear (✕)
/// button; [obscure] / [onToggleObscure] add the show / hide eye for a
/// password.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final VoidCallback onClear;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.onClear,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: !obscure && onToggleObscure == null,
      style: const TextStyle(
        color: authBlue,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 22, color: Colors.black54),
        floatingLabelStyle: const TextStyle(
          fontSize: 22,
          color: authBlue,
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: Icon(icon, color: Colors.black54),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: border(Colors.grey.shade400, 1),
        enabledBorder: border(Colors.grey.shade400, 1),
        focusedBorder: border(authBlue, 2),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggleObscure != null)
              IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                  color: Colors.black54,
                ),
                onPressed: onToggleObscure,
              ),
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear, color: Colors.black54),
              onPressed: onClear,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// The main button of a screen (Login / Register): full width, 64 high,
/// rounded, grey with black text like the app's buttons — shows a
/// spinner while [loading].
class AuthMainButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const AuthMainButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 2,
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: Colors.black,
            strokeWidth: 3,
          ),
        )
            : Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

/// A thin line with a word in the middle ("or").
class AuthDivider extends StatelessWidget {
  final String text;
  const AuthDivider({super.key, this.text = 'or'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(fontSize: 22, color: Colors.black54),
          ),
        ),
        const Expanded(child: Divider(thickness: 1)),
      ],
    );
  }
}

/// A small round grey button with a black arrow (back).
class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  const AuthBackButton({super.key, required this.onTap, this.tooltip = 'Back'});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.grey.shade300,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.arrow_back, color: Colors.black, size: 28),
          ),
        ),
      ),
    );
  }
}