import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/rtmp_destination.dart';
import 'rtmp_bloc.dart';

class RtmpPanel extends StatefulWidget {
  const RtmpPanel({super.key});

  @override
  State<RtmpPanel> createState() => _RtmpPanelState();
}

class _RtmpPanelState extends State<RtmpPanel> {
  final _platform = TextEditingController(text: 'YouTube');
  final _url = TextEditingController(text: 'rtmp://a.rtmp.youtube.com/live2');
  final _key = TextEditingController();

  @override
  void dispose() {
    _platform.dispose();
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RTMP Destinations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: const [
                Chip(label: Text('YouTube')),
                Chip(label: Text('Facebook')),
                Chip(label: Text('Instagram')),
                Chip(label: Text('Twitch')),
                Chip(label: Text('Custom')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _platform,
              decoration: const InputDecoration(labelText: 'Platform name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'RTMP URL'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _key,
              decoration: const InputDecoration(labelText: 'Stream key'),
            ),
            const SizedBox(height: 12),
            BlocConsumer<RtmpBloc, RtmpState>(
              listener: (context, state) {
                if (state is RtmpError) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              builder: (context, state) {
                return FilledButton.icon(
                  onPressed: () {
                    context.read<RtmpBloc>().add(
                      SaveRtmpDestination(
                        RtmpDestination(
                          destinationId: const Uuid().v4(),
                          platformName: _platform.text.trim(),
                          rtmpUrl: _url.text.trim(),
                          streamKey: _key.text.trim(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save RTMP'),
                );
              },
            ),
            const Divider(height: 28),
            BlocBuilder<RtmpBloc, RtmpState>(
              builder: (context, state) {
                final items = state is RtmpLoaded
                    ? state.destinations
                    : <RtmpDestination>[];
                if (items.isEmpty) {
                  return const Text('No RTMP targets saved yet.');
                }
                return Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.enabled
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                        ),
                        title: Text(item.platformName),
                        subtitle: Text(
                          item.pushUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
