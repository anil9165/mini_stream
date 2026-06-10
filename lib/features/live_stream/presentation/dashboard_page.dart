import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/config/agora_config_repository.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/agora_service.dart';
import '../../../shared/models/agora_config.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/live_stream.dart';
import '../../../shared/models/rtmp_destination.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../auth/presentation/auth_bloc.dart';
import '../../rtmp/presentation/rtmp_bloc.dart';
import '../../rtmp/presentation/rtmp_panel.dart';
import 'live_room_page.dart';
import 'live_stream_bloc.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.user});

  final AppUser user;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _tabIndex = 0;
  String? _openedRoomId;

  bool get _isAdmin => widget.user.role == 'admin';
  bool get _isSuperAdmin => widget.user.role == 'superadmin';

  @override
  void initState() {
    super.initState();
    context.read<LiveStreamBloc>().add(WatchLiveStreams());
    if (_isAdmin) {
      context.read<RtmpBloc>().add(WatchRtmpDestinations());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LiveStreamBloc, LiveStreamState>(
      listener: _listenForLiveState,
      builder: (context, state) {
        final studio = state is LiveStudioState
            ? state
            : const LiveStudioState();
        final pages = <Widget>[
          _HomeTab(user: widget.user, state: studio),
          if (_isAdmin) _GoLiveTab(user: widget.user, state: studio),
          if (_isAdmin) const _RestreamTab(),
          if (_isSuperAdmin) _SuperAdminConfigTab(user: widget.user),
          _ProfileTab(user: widget.user),
        ];
        final destinations = <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv),
            label: 'Live',
          ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.wifi_tethering),
              selectedIcon: Icon(Icons.wifi_tethering),
              label: 'Go Live',
            ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.cloud_upload_outlined),
              selectedIcon: Icon(Icons.cloud_done),
              label: 'Restream',
            ),
          if (_isSuperAdmin)
            const NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Config',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ];

        final selectedIndex = _tabIndex.clamp(0, pages.length - 1);
        return Scaffold(
          appBar: AppBar(
            title: const Text(AppConstants.appName),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: StatusChip(
                    label: _isSuperAdmin
                        ? 'SUPER ADMIN'
                        : _isAdmin
                        ? 'ADMIN'
                        : 'USER',
                    color: _isSuperAdmin
                        ? Colors.amberAccent
                        : _isAdmin
                        ? Colors.tealAccent
                        : Colors.lightBlueAccent,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Logout',
                onPressed: () => context.read<AuthBloc>().add(AuthSignedOut()),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Stack(
            children: [
              IndexedStack(index: selectedIndex, children: pages),
              if (studio.isLoading)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => setState(() => _tabIndex = index),
            destinations: destinations,
          ),
        );
      },
    );
  }

  void _listenForLiveState(BuildContext context, LiveStreamState state) {
    final studio = state is LiveStudioState ? state : null;
    if (studio == null) return;
    final error = studio.errorMessage;
    final info = studio.infoMessage;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else if (info != null &&
        !info.contains('Joined') &&
        !info.contains('started')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(info)));
    }

    final roomStream = studio.activeHostStream ?? studio.joinedStream;
    if (roomStream == null || _openedRoomId == roomStream.streamId) return;
    _openedRoomId = roomStream.streamId;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => LiveRoomPage(stream: roomStream, user: widget.user),
            fullscreenDialog: true,
          ),
        )
        .then((_) => _openedRoomId = null);
  }
}

Future<bool> _ensureHostLivePermissions(BuildContext context) async {
  final currentCamera = await Permission.camera.status;
  final currentMic = await Permission.microphone.status;
  if (currentCamera.isGranted && currentMic.isGranted) return true;

  if (currentCamera.isPermanentlyDenied || currentMic.isPermanentlyDenied) {
    if (!context.mounted) return false;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions required'),
        content: const Text(
          'Live start karne ke liye Camera aur Microphone permission required hai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await openAppSettings();
    }
    return false;
  }

  final statuses = await [Permission.camera, Permission.microphone].request();
  final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
  final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
  if (cameraGranted && micGranted) return true;

  if (!context.mounted) return false;
  final missing = [
    if (!cameraGranted) 'Camera',
    if (!micGranted) 'Microphone',
  ].join(' and ');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$missing permission required hai. Live create nahi hua.'),
    ),
  );
  return false;
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.user, required this.state});

  final AppUser user;
  final LiveStudioState state;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _WelcomeBand(user: user)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Live now',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (state.streams.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: 'No live streams yet',
              subtitle: user.role == 'admin'
                  ? 'Start a live session from Go Live and it will appear here.'
                  : 'Admin live streams will appear here when they are online.',
              icon: Icons.live_tv_outlined,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.builder(
              itemCount: state.streams.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 460,
                mainAxisExtent: 284,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) => _LiveStreamCard(
                stream: state.streams[index],
                user: user,
                state: state,
              ),
            ),
          ),
      ],
    );
  }
}

class _WelcomeBand extends StatelessWidget {
  const _WelcomeBand({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'admin';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF062A2A), Color(0xFF14243A), Color(0xFF2B1736)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAdmin ? Icons.admin_panel_settings_outlined : Icons.play_circle,
              color: Colors.tealAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi ${user.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'Host live rooms and restream to YouTube, Facebook, Twitch, Instagram endpoints, or any RTMP target.'
                      : 'Watch active live rooms, chat, send reactions, and leave anytime.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStreamCard extends StatelessWidget {
  const _LiveStreamCard({
    required this.stream,
    required this.user,
    required this.state,
  });

  final LiveStream stream;
  final AppUser user;
  final LiveStudioState state;

  @override
  Widget build(BuildContext context) {
    final isOwnHostLive = user.role == 'admin' && stream.hostId == user.uid;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => isOwnHostLive
            ? _rejoinOrOpenRoom(context, stream)
            : context.read<LiveStreamBloc>().add(JoinLive(stream)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.teal.shade900,
                          Colors.indigo.shade900,
                          Colors.pink.shade900,
                        ],
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const Positioned(
                    left: 10,
                    top: 10,
                    child: StatusChip(label: 'LIVE', color: Colors.redAccent),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Chip(
                      avatar: const Icon(Icons.visibility_outlined, size: 16),
                      label: Text('${stream.viewerCount}'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stream.description.isEmpty
                        ? 'Channel ${stream.channelName}'
                        : stream.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isOwnHostLive) ...[
                    const SizedBox(height: 10),
                    _HostLiveActions(
                      stream: stream,
                      user: user,
                      hostRole: user.role,
                      isActiveLocally:
                          state.activeHostStream?.streamId == stream.streamId,
                      isLoading: state.isLoading,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejoinOrOpenRoom(
    BuildContext context,
    LiveStream stream,
  ) async {
    final allowed = await _ensureHostLivePermissions(context);
    if (!allowed || !context.mounted) return;
    if (state.activeHostStream?.streamId != stream.streamId) {
      context.read<LiveStreamBloc>().add(
        RejoinHostLive(stream, hostRole: user.role),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveRoomPage(stream: stream, user: user),
        fullscreenDialog: true,
      ),
    );
  }
}

class _GoLiveTab extends StatefulWidget {
  const _GoLiveTab({required this.user, required this.state});

  final AppUser user;
  final LiveStudioState state;

  @override
  State<_GoLiveTab> createState() => _GoLiveTabState();
}

class _GoLiveTabState extends State<_GoLiveTab> {
  final _title = TextEditingController(text: 'Mini Live Show');
  final _description = TextEditingController(text: 'Live from Mini Live.');

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final created = widget.state.createdStream;
    final active = widget.state.activeHostStream;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HostPreviewCard(user: widget.user),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create live',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Live title',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          widget.state.isLoading || widget.state.isHostLive
                          ? null
                          : () => _createLive(context),
                      icon: widget.state.isLoading
                          ? const _ButtonProgressIcon()
                          : const Icon(Icons.add_circle_outline),
                      label: Text(
                        widget.state.isLoading ? 'Creating...' : 'Create',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (active != null) ...[
          _ActiveHostLiveCard(
            stream: active,
            user: widget.user,
            hostRole: widget.user.role,
            isLoading: widget.state.isLoading,
          ),
          const SizedBox(height: 12),
        ],
        if (created == null)
          const _NoCreatedLiveCard()
        else
          _CreatedLiveCard(
            stream: created,
            isLoading: widget.state.isLoading,
            onStart: () => _startLive(context, created),
            onDelete: () => _deleteLive(context, created),
          ),
      ],
    );
  }

  Future<void> _createLive(BuildContext context) async {
    final allowed = await _ensureHostLivePermissions(context);
    if (!allowed || !context.mounted) return;
    context.read<LiveStreamBloc>().add(
      CreateLive(
        hostId: widget.user.uid,
        hostRole: widget.user.role,
        title: _title.text.trim(),
        description: _description.text.trim(),
      ),
    );
  }

  Future<void> _startLive(BuildContext context, LiveStream stream) async {
    final allowed = await _ensureHostLivePermissions(context);
    if (!allowed || !context.mounted) return;
    final rtmp = context.read<RtmpBloc>().state;
    final destinations = rtmp is RtmpLoaded
        ? rtmp.destinations
        : <RtmpDestination>[];
    context.read<LiveStreamBloc>().add(
      StartLive(stream, destinations, hostRole: widget.user.role),
    );
  }

  void _deleteLive(BuildContext context, LiveStream stream) {
    context.read<LiveStreamBloc>().add(DeleteLive(stream, const []));
  }
}

class _NoCreatedLiveCard extends StatelessWidget {
  const _NoCreatedLiveCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event_available_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No created live yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  const Text('Create a live first. It will appear here.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatedLiveCard extends StatelessWidget {
  const _CreatedLiveCard({
    required this.stream,
    required this.isLoading,
    required this.onStart,
    required this.onDelete,
  });

  final LiveStream stream;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C2F2A), Color(0xFF142334), Color(0xFF2D1C33)],
        ),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: .25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const StatusChip(
                  label: 'READY TO START',
                  color: Colors.tealAccent,
                ),
                const Spacer(),
                Text(
                  stream.channelName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              stream.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              stream.description.isEmpty
                  ? 'No description added'
                  : stream.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onStart,
                    icon: isLoading
                        ? const _ButtonProgressIcon()
                        : const Icon(Icons.wifi_tethering),
                    label: Text(isLoading ? 'Starting...' : 'Start Live Now'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Delete draft',
                  onPressed: isLoading ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveHostLiveCard extends StatelessWidget {
  const _ActiveHostLiveCard({
    required this.stream,
    required this.user,
    required this.hostRole,
    required this.isLoading,
  });

  final LiveStream stream;
  final AppUser user;
  final String hostRole;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF111418),
        border: Border.all(color: Colors.redAccent.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const StatusChip(label: 'LIVE NOW', color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stream.channelName,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stream.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              stream.description.isEmpty
                  ? 'Your live room is running.'
                  : stream.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            _HostLiveActions(
              stream: stream,
              user: user,
              hostRole: hostRole,
              isActiveLocally: true,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _HostLiveActions extends StatelessWidget {
  const _HostLiveActions({
    required this.stream,
    required this.user,
    required this.hostRole,
    required this.isActiveLocally,
    required this.isLoading,
  });

  final LiveStream stream;
  final AppUser user;
  final String hostRole;
  final bool isActiveLocally;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: isLoading ? null : () => _openRoom(context),
          icon: isLoading
              ? const _ButtonProgressIcon()
              : const Icon(Icons.meeting_room_outlined),
          label: Text(isLoading ? 'Opening...' : 'Rejoin'),
        ),
        OutlinedButton.icon(
          onPressed: isLoading ? null : () => _endLive(context),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('End'),
        ),
        IconButton.filledTonal(
          tooltip: 'Delete meeting',
          onPressed: isLoading ? null : () => _deleteLive(context),
          icon: const Icon(Icons.delete_forever_outlined),
        ),
      ],
    );
  }

  Future<void> _openRoom(BuildContext context) async {
    final allowed = await _ensureHostLivePermissions(context);
    if (!allowed || !context.mounted) return;
    if (!isActiveLocally) {
      context.read<LiveStreamBloc>().add(
        RejoinHostLive(stream, hostRole: hostRole),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveRoomPage(stream: stream, user: user),
        fullscreenDialog: true,
      ),
    );
  }

  void _endLive(BuildContext context) {
    final rtmp = context.read<RtmpBloc>().state;
    final destinations = rtmp is RtmpLoaded
        ? rtmp.destinations
        : <RtmpDestination>[];
    context.read<LiveStreamBloc>().add(EndLive(stream, destinations));
  }

  void _deleteLive(BuildContext context) {
    final rtmp = context.read<RtmpBloc>().state;
    final destinations = rtmp is RtmpLoaded
        ? rtmp.destinations
        : <RtmpDestination>[];
    context.read<LiveStreamBloc>().add(DeleteLive(stream, destinations));
  }
}

class _ButtonProgressIcon extends StatelessWidget {
  const _ButtonProgressIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _HostPreviewCard extends StatelessWidget {
  const _HostPreviewCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1014), Color(0xFF173235), Color(0xFF2E2147)],
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.videocam_outlined,
              size: 64,
              color: Colors.white70,
            ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            right: 14,
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const StatusChip(label: 'READY', color: Colors.tealAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestreamTab extends StatelessWidget {
  const _RestreamTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [RtmpPanel()],
    );
  }
}

class _SuperAdminConfigTab extends StatefulWidget {
  const _SuperAdminConfigTab({required this.user});

  final AppUser user;

  @override
  State<_SuperAdminConfigTab> createState() => _SuperAdminConfigTabState();
}

class _SuperAdminConfigTabState extends State<_SuperAdminConfigTab> {
  final _appId = TextEditingController();
  final _channel = TextEditingController();
  final _token = TextEditingController();
  String? _loadedKey;
  bool _saving = false;

  IAgoraConfigRepository get _repo => sl<IAgoraConfigRepository>();

  @override
  void dispose() {
    _appId.dispose();
    _channel.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AgoraConfig>(
      stream: _repo.watchConfig(),
      initialData: AgoraConfig.defaults(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? AgoraConfig.defaults();
        _syncControllers(config);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Agora configuration',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const StatusChip(
                          label: 'SUPER ADMIN',
                          color: Colors.amberAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Host live chal raha ho toh config save block rahega. Save ke baad new live rooms updated Agora values use karenge.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _appId,
                      decoration: const InputDecoration(
                        labelText: 'Agora App ID',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _channel,
                      decoration: const InputDecoration(
                        labelText: 'Agora Channel',
                        prefixIcon: Icon(Icons.tag_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _token,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Agora Temp Token',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _saveConfig(context),
                      icon: _saving
                          ? const _ButtonProgressIcon()
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save config'),
                    ),
                    if (config.updatedAt != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Last updated: ${config.updatedAt}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _syncControllers(AgoraConfig config) {
    final key = '${config.appId}|${config.channelName}|${config.tempToken}';
    if (_loadedKey == key) return;
    _loadedKey = key;
    _appId.text = config.appId;
    _channel.text = config.channelName;
    _token.text = config.tempToken;
  }

  Future<void> _saveConfig(BuildContext context) async {
    final appId = _appId.text.trim();
    final channel = _channel.text.trim();
    final token = _token.text.trim();
    if (appId.isEmpty || channel.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App ID, channel, and token required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.updateConfig(
        AgoraConfig(appId: appId, channelName: channel, tempToken: token),
        updatedBy: widget.user.uid,
      );
      await sl<IAgoraService>().destroy();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Agora config updated.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 38,
                  child: Icon(Icons.person, size: 36),
                ),
                const SizedBox(height: 12),
                Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(user.email.isEmpty ? 'Guest account' : user.email),
                const SizedBox(height: 10),
                StatusChip(
                  label: user.role == 'superadmin'
                      ? 'SUPER ADMIN'
                      : user.role == 'admin'
                      ? 'ADMIN HOST'
                      : 'USER VIEWER',
                  color: user.role == 'superadmin'
                      ? Colors.amberAccent
                      : user.role == 'admin'
                      ? Colors.tealAccent
                      : Colors.lightBlueAccent,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.read<AuthBloc>().add(AuthSignedOut()),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
