import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/providers.dart';
import '../../../core/network/api_error_message.dart';
import '../domain/call_session.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({required this.callId, super.key});

  final String callId;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  late Future<CallSession> _call;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _call = ref.read(callRepositoryProvider).get(widget.callId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cuộc gọi đến')),
    body: FutureBuilder<CallSession>(
      future: _call,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Không tải được cuộc gọi: ${apiErrorMessage(snapshot.error!)}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final call = snapshot.data!;
        if (call.status != 'RINGING') {
          return Center(child: Text('Cuộc gọi ${_status(call.status)}.'));
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 42,
                  child: Icon(Icons.videocam, size: 40),
                ),
                const SizedBox(height: 18),
                Text(
                  '${call.callerName ?? 'Sinh viên'} đang gọi video cho bạn',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _reject(),
                      icon: const Icon(Icons.call_end),
                      label: const Text('Từ chối'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _accept(),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Chấp nhận'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final call = await ref.read(callRepositoryProvider).accept(widget.callId);
      if (!call.hasAgoraCredentials) {
        throw StateError('Máy chủ chưa cấu hình Agora.');
      }
      if (mounted) context.go('/calls/${call.id}/video', extra: call);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể nhận cuộc gọi: ${apiErrorMessage(error)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref.read(callRepositoryProvider).reject(widget.callId);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể từ chối cuộc gọi: ${apiErrorMessage(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class OutgoingCallScreen extends ConsumerStatefulWidget {
  const OutgoingCallScreen({required this.callId, super.key});

  final String callId;

  @override
  ConsumerState<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends ConsumerState<OutgoingCallScreen> {
  Timer? _timer;
  String _status = 'RINGING';
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final call = await ref.read(callRepositoryProvider).get(widget.callId);
      if (!mounted) return;
      if (call.status == 'ACCEPTED' && call.hasAgoraCredentials) {
        _timer?.cancel();
        context.go('/calls/${call.id}/video', extra: call);
        return;
      }
      setState(() {
        _status = call.status;
        _error = null;
      });
      if (call.status != 'RINGING') _timer?.cancel();
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đang gọi')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _status == 'RINGING'
                ? 'Đang chờ chủ trọ nhận cuộc gọi...'
                : 'Cuộc gọi ${_status.toLowerCase()}',
          ),
          if (_error != null) Text(_error!),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              try {
                await ref.read(callRepositoryProvider).end(widget.callId);
                if (context.mounted) context.go('/home');
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Không thể kết thúc cuộc gọi: ${apiErrorMessage(error)}',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.call_end),
            label: const Text('Hủy cuộc gọi'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    ),
  );
}

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({required this.call, super.key});

  final CallSession call;

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _muted = false;
  bool _speaker = true;
  bool _cameraOn = true;
  String? _error;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _startCall();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkCall(),
    );
  }

  Future<void> _startCall() async {
    try {
      final camera = await Permission.camera.request();
      final microphone = await Permission.microphone.request();
      if (!camera.isGranted || !microphone.isGranted) {
        throw StateError('Cần cấp quyền camera và microphone để gọi video.');
      }
      final call = widget.call;
      if (!call.hasAgoraCredentials) {
        throw StateError('Thiếu token Agora hợp lệ từ máy chủ.');
      }
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(RtcEngineContext(appId: call.appId!));
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (_, uid, _) {
            if (mounted) setState(() => _remoteUid = uid);
          },
          onUserOffline: (_, _, _) {
            if (mounted) {
              setState(() => _remoteUid = null);
              _endCall();
            }
          },
          onError: (_, message) {
            if (mounted) setState(() => _error = message);
          },
        ),
      );
      await engine.enableVideo();
      await engine.startPreview();
      await engine.joinChannel(
        token: call.token!,
        channelId: call.channelName,
        uid: call.uid!,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    }
  }

  Future<void> _checkCall() async {
    try {
      final call = await ref.read(callRepositoryProvider).get(widget.call.id);
      if (call.status == 'ENDED' ||
          call.status == 'REJECTED' ||
          call.status == 'MISSED') {
        _statusTimer?.cancel();
        if (mounted) context.go('/home');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Mất kết nối máy chủ: ${apiErrorMessage(error)}',
        );
      }
    }
  }

  Future<void> _endCall() async {
    try {
      await ref.read(callRepositoryProvider).end(widget.call.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không cập nhật được trạng thái cuộc gọi: $error'),
          ),
        );
      }
    } finally {
      if (mounted) context.go('/home');
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    final engine = _engine;
    if (engine != null) {
      engine.leaveChannel();
      engine.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: engine == null || _remoteUid == null
                  ? Center(
                      child: Text(
                        _error ?? 'Đang kết nối cuộc gọi...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: engine,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection: RtcConnection(
                          channelId: widget.call.channelName,
                        ),
                      ),
                    ),
            ),
            if (engine != null)
              Positioned(
                right: 16,
                top: 48,
                width: 120,
                height: 170,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _control(Icons.mic, _muted, () async {
                    await engine?.muteLocalAudioStream(!_muted);
                    if (mounted) setState(() => _muted = !_muted);
                  }),
                  _control(Icons.volume_up, !_speaker, () async {
                    await engine?.setEnableSpeakerphone(!_speaker);
                    if (mounted) setState(() => _speaker = !_speaker);
                  }),
                  _control(Icons.videocam, !_cameraOn, () async {
                    await engine?.enableLocalVideo(!_cameraOn);
                    if (mounted) setState(() => _cameraOn = !_cameraOn);
                  }),
                  _control(Icons.cameraswitch, false, () async {
                    await engine?.switchCamera();
                  }),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _endCall,
                    child: const Icon(Icons.call_end),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _control(IconData icon, bool active, Future<void> Function() onTap) =>
      IconButton.filled(
        onPressed: () async {
          try {
            await onTap();
          } catch (error) {
            if (mounted) setState(() => _error = 'Lỗi thiết bị gọi: $error');
          }
        },
        icon: Icon(icon),
        color: active ? Colors.red : Colors.white,
        style: IconButton.styleFrom(backgroundColor: Colors.black54),
      );
}

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  late Future<List<CallSession>> _calls;

  @override
  void initState() {
    super.initState();
    _calls = ref.read(callRepositoryProvider).history();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử cuộc gọi')),
    body: FutureBuilder<List<CallSession>>(
      future: _calls,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Không tải được lịch sử: ${apiErrorMessage(snapshot.error!)}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Chưa có cuộc gọi nào.'));
        }
        return ListView(
          children: snapshot.data!
              .map(
                (call) => ListTile(
                  leading: const Icon(Icons.video_call_outlined),
                  title: Text(
                    call.callerName ??
                        call.receiverName ??
                        'Cuộc gọi phòng trọ',
                  ),
                  subtitle: Text('${call.status} · ${call.roomId}'),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

String _status(String status) => switch (status) {
  'REJECTED' => 'bị từ chối',
  'MISSED' => 'nhỡ',
  'ENDED' => 'đã kết thúc',
  _ => 'không khả dụng',
};
