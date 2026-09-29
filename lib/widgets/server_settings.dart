import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ewaste_service.dart';
import '../utils/constants.dart';

/// Lets the member point the app at the EcoCollect server.
Future<void> showServerDialog(BuildContext context) async {
  final service = context.read<EwasteService>();
  final controller = TextEditingController(text: service.serverUrl);
  final url = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Server address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Use the address printed by the EcoCollect server, for example http://192.168.1.10:8787.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'http://…:8787'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (url != null) await service.setServerUrl(url);
}

/// "Server: host · Change" line for the sign-in screens.
class ServerLine extends StatelessWidget {
  const ServerLine({super.key});

  @override
  Widget build(BuildContext context) {
    final url = context.watch<EwasteService>().serverUrl;
    final host = url.replaceFirst(RegExp(r'^https?://'), '');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.dns_outlined, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            host.isEmpty ? 'No server set' : 'Server: $host',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => showServerDialog(context),
          child: const Text('Change'),
        ),
      ],
    );
  }
}
