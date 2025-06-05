import 'package:flutter/material.dart';

class InstructionEditor extends StatefulWidget {
  final List<String> initialInstructions;

  const InstructionEditor({super.key, required this.initialInstructions});

  @override
  State<InstructionEditor> createState() => _InstructionEditorState();
}

class _InstructionEditorState extends State<InstructionEditor> {
  List<TextEditingController> controllers = [];

  @override
  void initState() {
    super.initState();
    controllers =
        widget.initialInstructions
            .map((text) => TextEditingController(text: text))
            .toList();
    if (controllers.isEmpty) {
      controllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleEnterPressed(int index, TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid) return;

    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);

    setState(() {
      controller.text = before;
      controller.selection = TextSelection.collapsed(offset: before.length);
      final newController = TextEditingController(text: after);
      controllers.insert(index + 1, newController);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(controllers.length, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: TextFormField(
            controller: controllers[i],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Instruktion',
            ),
            onFieldSubmitted: (_) => _handleEnterPressed(i, controllers[i]),
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            maxLines: null,
          ),
        );
      }),
    );
  }
}
