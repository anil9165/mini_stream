import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/agora_service.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/live_stream.dart';
import '../../../shared/models/rtmp_destination.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../rtmp/presentation/rtmp_bloc.dart';
import 'live_stream_bloc.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key, required this.stream, required this.user});

  final LiveStream stream;
  final AppUser user;

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  final _message = TextEditingController();
  final _reactions = <_FloatingReaction>[];
  final _seenReactionIds = <String>{};
  bool _overlayVisible = true;
  bool _leaving = false;
  bool _micMuted = false;
  bool _cameraMuted = false;

  @override
  void initState() {
    super.initState();
    _micMuted = widget.stream.hostMicMuted;
    _cameraMuted = widget.stream.hostCameraOff;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LiveStreamBloc, LiveStreamState>(
      listener: (context, state) {
        if (_leaving || state is! LiveStudioState) return;
        final stillInRoom =
            state.activeHostStream?.streamId == widget.stream.streamId ||
            state.joinedStream?.streamId == widget.stream.streamId;
        if (!stillInRoom && !state.isLoading) {
          final wasAudience =
              state.joinedStream?.streamId == widget.stream.streamId;
          setState(() => _leaving = true);
          if (wasAudience) {
            context.read<LiveStreamBloc>().add(LeaveLive(widget.stream));
          }
          _popRoom();
        }
      },
      builder: (context, state) {
        final studio = state is LiveStudioState
            ? state
            : const LiveStudioState();
        final isHost =
            studio.activeHostStream?.streamId == widget.stream.streamId;
        final activeStream =
            studio.activeHostStream ?? studio.joinedStream ?? widget.stream;
        final micMuted = isHost ? _micMuted : activeStream.hostMicMuted;
        final cameraOff = isHost ? _cameraMuted : activeStream.hostCameraOff;
        final videoReady = sl<IAgoraService>().engine != null;
        return PopScope(
          canPop: _leaving,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _closeRoom(context, activeStream, isHost);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                _LiveVideoSurface(stream: activeStream, isHost: isHost),
                if (_overlayVisible)
                  _LiveGradientOverlay(
                    stream: activeStream,
                    isHost: isHost,
                    micMuted: micMuted,
                    cameraMuted: cameraOff,
                  ),
                if (_overlayVisible && videoReady)
                  Positioned(
                    left: 12,
                    right: 78,
                    bottom: 84 + MediaQuery.paddingOf(context).bottom,
                    child: _LiveChatOverlay(
                      streamId: widget.stream.streamId,
                      onReactionAdded: _showReaction,
                      seenReactionIds: _seenReactionIds,
                    ),
                  ),
                ..._reactions.map(
                  (reaction) => _ReactionBubble(reaction: reaction),
                ),
                if (videoReady)
                  Positioned(
                    right: 12,
                    top: 104 + MediaQuery.paddingOf(context).top,
                    child: _LiveActionRail(
                      overlayVisible: _overlayVisible,
                      isHost: isHost,
                      micMuted: micMuted,
                      cameraMuted: cameraOff,
                      onToggleOverlay: () =>
                          setState(() => _overlayVisible = !_overlayVisible),
                      onToggleMic: () => _toggleMic(activeStream),
                      onToggleCamera: () => _toggleCamera(activeStream),
                      onClose: () => _closeRoom(context, activeStream, isHost),
                      onEnd: () => _endRoom(context, activeStream),
                    ),
                  ),
                if (videoReady)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12 + MediaQuery.paddingOf(context).bottom,
                    child: _LiveRoomControls(
                      controller: _message,
                      onEmoji: _sendEmoji,
                      onSend: _sendMessage,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendMessage() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    _message.clear();
    unawaited(_sendChatMessage(text: text, type: 'message'));
  }

  void _sendEmoji(String emoji) {
    _showReaction(emoji);
    unawaited(_sendChatMessage(text: emoji, type: 'reaction'));
  }

  Future<void> _sendChatMessage({
    required String text,
    required String type,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.stream.streamId)
          .collection('messages')
          .add({
            'authorId': widget.user.uid,
            'authorName': widget.user.name,
            'text': text,
            'type': type,
            'createdAt': FieldValue.serverTimestamp(),
            'clientCreatedAt': Timestamp.now(),
          });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Message failed: $error')));
    }
  }

  void _showReaction(String emoji) {
    final random = Random();
    final reaction = _FloatingReaction(
      emoji: emoji,
      leftFactor: .15 + random.nextDouble() * .65,
      id: DateTime.now().microsecondsSinceEpoch,
    );
    setState(() => _reactions.add(reaction));
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _reactions.removeWhere((item) => item.id == reaction.id));
    });
  }

  Future<void> _toggleMic(LiveStream stream) async {
    final muted = !_micMuted;
    setState(() => _micMuted = muted);
    await sl<IAgoraService>().setLocalAudioMuted(muted);
    if (!mounted) return;
    context.read<LiveStreamBloc>().add(
      HostControlsChanged(
        stream: stream,
        micMuted: muted,
        cameraOff: _cameraMuted,
      ),
    );
  }

  Future<void> _toggleCamera(LiveStream stream) async {
    final muted = !_cameraMuted;
    setState(() => _cameraMuted = muted);
    await sl<IAgoraService>().setLocalVideoMuted(muted);
    if (!mounted) return;
    context.read<LiveStreamBloc>().add(
      HostControlsChanged(
        stream: stream,
        micMuted: _micMuted,
        cameraOff: muted,
      ),
    );
  }

  Future<void> _closeRoom(
    BuildContext context,
    LiveStream stream,
    bool isHost,
  ) async {
    if (_leaving) {
      _popRoom();
      return;
    }
    final liveBloc = context.read<LiveStreamBloc>();

    setState(() => _leaving = true);
    if (isHost) {
      liveBloc.add(LeaveHostRoom(stream));
    } else {
      liveBloc.add(LeaveLive(stream));
    }
    _popRoom();
  }

  Future<void> _endRoom(BuildContext context, LiveStream stream) async {
    if (_leaving) {
      _popRoom();
      return;
    }
    final rtmp = context.read<RtmpBloc>().state;
    final destinations = rtmp is RtmpLoaded
        ? rtmp.destinations
        : <RtmpDestination>[];
    setState(() => _leaving = true);
    context.read<LiveStreamBloc>().add(EndLive(stream, destinations));
    _popRoom();
  }

  void _popRoom() {
    final navigator = Navigator.of(context);
    navigator.pop();
  }
}

class _LiveVideoSurface extends StatelessWidget {
  const _LiveVideoSurface({required this.stream, required this.isHost});

  final LiveStream stream;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final agora = sl<IAgoraService>();
    final engine = agora.engine;
    if (engine == null) {
      return const _RoomPlaceholder(title: 'Preparing live video');
    }
    if (isHost && stream.hostCameraOff) {
      return const _RoomPlaceholder(title: 'Camera is off');
    }
    if (isHost) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
          useFlutterTexture: false,
        ),
      );
    }
    return StreamBuilder<List<int>>(
      stream: agora.remoteUsers,
      initialData: agora.currentRemoteUsers,
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <int>[];
        if (!stream.hostPresent ||
            users.isEmpty ||
            agora.activeChannelName == null) {
          return const _RoomPlaceholder(title: 'Waiting for host');
        }
        if (stream.hostCameraOff) {
          return const _RoomPlaceholder(title: 'Host camera is off');
        }
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: engine,
            canvas: VideoCanvas(uid: users.first),
            connection: RtcConnection(channelId: agora.activeChannelName),
            useFlutterTexture: false,
          ),
        );
      },
    );
  }
}

class _RoomPlaceholder extends StatelessWidget {
  const _RoomPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_outlined, size: 58, color: Colors.white70),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _LiveGradientOverlay extends StatelessWidget {
  const _LiveGradientOverlay({
    required this.stream,
    required this.isHost,
    this.micMuted = false,
    this.cameraMuted = false,
  });

  final LiveStream stream;
  final bool isHost;
  final bool micMuted;
  final bool cameraMuted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
          stops: [0, .45, 1],
        ),
      ),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const StatusChip(label: 'LIVE', color: Colors.redAccent),
                    StatusChip(
                      label: '${stream.viewerCount} watching',
                      color: Colors.lightBlueAccent,
                    ),
                    if (!stream.hostPresent)
                      const StatusChip(
                        label: 'HOST AWAY',
                        color: Colors.amberAccent,
                      ),
                    if (micMuted)
                      StatusChip(
                        label: isHost ? 'MIC MUTED' : 'HOST MUTED',
                        color: Colors.orangeAccent,
                      ),
                    if (cameraMuted)
                      StatusChip(
                        label: isHost ? 'CAMERA OFF' : 'HOST CAMERA OFF',
                        color: Colors.orangeAccent,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  stream.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveChatOverlay extends StatelessWidget {
  const _LiveChatOverlay({
    required this.streamId,
    required this.onReactionAdded,
    required this.seenReactionIds,
  });

  final String streamId;
  final ValueChanged<String> onReactionAdded;
  final Set<String> seenReactionIds;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('live_streams')
        .doc(streamId)
        .collection('messages')
        .orderBy('clientCreatedAt', descending: true)
        .limit(24);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final messages = docs.reversed.map(_LiveMessage.fromDoc).toList();
        for (final message in messages) {
          if (message.type != 'reaction') continue;
          if (!seenReactionIds.add(message.id)) continue;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onReactionAdded(message.text);
          });
        }
        final visible = messages.length > 5
            ? messages.sublist(messages.length - 5)
            : messages;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visible.isEmpty)
              const _LiveMessageBubble(
                message: _LiveMessage(
                  id: 'welcome',
                  author: 'Mini',
                  text: 'Welcome to the live room',
                  type: 'message',
                ),
              )
            else
              for (final message in visible)
                _LiveMessageBubble(message: message),
          ],
        );
      },
    );
  }
}

class _LiveMessageBubble extends StatelessWidget {
  const _LiveMessageBubble({required this.message});

  final _LiveMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${message.author}: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: message.text),
          ],
        ),
      ),
    );
  }
}

class _LiveRoomControls extends StatelessWidget {
  const _LiveRoomControls({
    required this.controller,
    required this.onEmoji,
    required this.onSend,
  });

  final TextEditingController controller;
  final ValueChanged<String> onEmoji;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        child: Row(
          children: [
            for (final emoji in const ['❤️', '🔥', '👏'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _MiniEmojiButton(
                  emoji: emoji,
                  onPressed: () => onEmoji(emoji),
                ),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Message',
                  hintStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .1),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 40,
              child: IconButton.filled(
                onPressed: onSend,
                icon: const Icon(Icons.send, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveActionRail extends StatelessWidget {
  const _LiveActionRail({
    required this.overlayVisible,
    required this.isHost,
    required this.micMuted,
    required this.cameraMuted,
    required this.onToggleOverlay,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onClose,
    required this.onEnd,
  });

  final bool overlayVisible;
  final bool isHost;
  final bool micMuted;
  final bool cameraMuted;
  final VoidCallback onToggleOverlay;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onClose;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailButton(
              tooltip: overlayVisible ? 'Hide overlay' : 'Show overlay',
              onPressed: onToggleOverlay,
              icon: overlayVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            if (isHost) ...[
              const SizedBox(height: 8),
              _RailButton(
                tooltip: micMuted ? 'Unmute mic' : 'Mute mic',
                onPressed: onToggleMic,
                icon: micMuted ? Icons.mic_off : Icons.mic,
                selected: micMuted,
              ),
              const SizedBox(height: 8),
              _RailButton(
                tooltip: cameraMuted ? 'Turn camera on' : 'Turn camera off',
                onPressed: onToggleCamera,
                icon: cameraMuted ? Icons.videocam_off : Icons.videocam,
                selected: cameraMuted,
              ),
            ],
            const SizedBox(height: 8),
            _RailButton(
              tooltip: isHost ? 'Leave room' : 'Leave live',
              onPressed: onClose,
              icon: isHost ? Icons.meeting_room_outlined : Icons.close,
            ),
            if (isHost) ...[
              const SizedBox(height: 8),
              _RailButton(
                tooltip: 'End live',
                onPressed: onEnd,
                icon: Icons.stop_circle_outlined,
                danger: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniEmojiButton extends StatelessWidget {
  const _MiniEmojiButton({required this.emoji, required this.onPressed});

  final String emoji;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Send $emoji',
      child: SizedBox.square(
        dimension: 36,
        child: IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .12),
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          icon: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.selected = false,
    this.danger = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? Colors.redAccent
        : selected
        ? Colors.orangeAccent
        : Colors.white.withValues(alpha: .16);
    final foreground = danger || selected ? Colors.black : Colors.white;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 44,
        child: IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 21),
        ),
      ),
    );
  }
}

class _ReactionBubble extends StatelessWidget {
  const _ReactionBubble({required this.reaction});

  final _FloatingReaction reaction;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: MediaQuery.sizeOf(context).width * reaction.leftFactor,
      bottom: 112,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -160 * value),
            child: Opacity(
              opacity: 1 - value,
              child: Text(reaction.emoji, style: const TextStyle(fontSize: 34)),
            ),
          );
        },
      ),
    );
  }
}

class _LiveMessage {
  const _LiveMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.type,
  });

  factory _LiveMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _LiveMessage(
      id: doc.id,
      author: (data['authorName'] as String?)?.trim().isNotEmpty == true
          ? data['authorName'] as String
          : 'Guest',
      text: data['text'] as String? ?? '',
      type: data['type'] as String? ?? 'message',
    );
  }

  final String id;
  final String author;
  final String text;
  final String type;
}

class _FloatingReaction {
  const _FloatingReaction({
    required this.emoji,
    required this.leftFactor,
    required this.id,
  });

  final String emoji;
  final double leftFactor;
  final int id;
}
