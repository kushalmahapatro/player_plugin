import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:player_plugin/player/model/secured_video_content.dart';


class PlayerPlugin {
  static const MethodChannel _channel =
      const MethodChannel('flutter.io/videoPlayer');

//  static Future<String> get platformVersion async {
//    final String version = await _channel.invokeMethod('getPlatformVersion');
//    return version;
//  }

}

class DurationRange {
  DurationRange(this.start, this.end);

  final Duration start;
  final Duration end;

  double startFraction(Duration duration) {
    return start.inMilliseconds / duration.inMilliseconds;
  }

  double endFraction(Duration duration) {
    return end.inMilliseconds / duration.inMilliseconds;
  }

  @override
  String toString() => '$runtimeType(start: $start, end: $end)';
}

class VideoPlayerValue {
  VideoPlayerValue(
      {@required this.duration,
      this.size,
      this.position = const Duration(),
      this.buffered = const <DurationRange>[],
      this.isPlaying = false,
      this.isLooping = false,
      this.isBuffering = false,
      this.volume = 1.0,
      this.speed = 1,
      this.resolutions = const <String>[],
      this.audios = const <String>[],
      this.subtitles = const <String>[],
      this.errorDescription,
      this.autoFormat});

  VideoPlayerValue.uninitialized() : this(duration: null);

  VideoPlayerValue.erroneous(String errorDescription)
      : this(duration: null, errorDescription: errorDescription);

  /// The total duration of the video.
  ///
  /// Is null when [initialized] is false.
  final Duration duration;

  /// The current playback position.
  final Duration position;

  /// The currently buffered ranges.
  final List<DurationRange> buffered;

  /// True if the video is playing. False if it's paused.
  final bool isPlaying;

  /// True if the video is looping.
  final bool isLooping;

  /// True if the video is currently buffering.
  final bool isBuffering;

  /// The current volume of the playback.
  final double volume;

  final double speed;

  final List<dynamic> resolutions;
  final List<dynamic> audios;
  final List<dynamic> subtitles;
  final String autoFormat;

  /// A description of the error if present.
  ///
  /// If [hasError] is false this is [null].
  final String errorDescription;

  /// The [size] of the currently loaded video.
  ///
  /// Is null when [initialized] is false.
  final Size size;

  bool get initialized => duration != null;

  bool get hasError => errorDescription != null;

  double get aspectRatio => size != null ? size.width / size.height : 1.0;

  VideoPlayerValue copyWith(
      {Duration duration,
      List<dynamic> resolutions,
      List<dynamic> audios,
      List<dynamic> subtitles,
      Size size,
      Duration position,
      List<DurationRange> buffered,
      bool isPlaying,
      bool isLooping,
      bool isBuffering,
      double volume,
      double speed,
      String errorDescription,
      String autoFormat}) {
    return VideoPlayerValue(
      duration: duration ?? this.duration,
      size: size ?? this.size,
      position: position ?? this.position,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isBuffering: isBuffering ?? this.isBuffering,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      resolutions: resolutions ?? this.resolutions,
      audios: audios ?? this.audios,
      subtitles: subtitles ?? this.subtitles,
      errorDescription: errorDescription ?? this.errorDescription,
      autoFormat: autoFormat ?? this.autoFormat,
    );
  }

  @override
  String toString() {
    return '$runtimeType('
        'duration: $duration, '
        'size: $size, '
        'position: $position, '
        'buffered: [${buffered.join(', ')}], '
        'isPlaying: $isPlaying, '
        'isLooping: $isLooping, '
        'isBuffering: $isBuffering'
        'volume: $volume, '
        'speed: $speed, '
        'resolutiosn: [${resolutions.join(', ')}], '
        'audios: [${audios.join(', ')}], '
        'subtitles: [${subtitles.join(', ')}], '
        'errorDescription: $errorDescription,'
        'autoFormat: $autoFormat)';
  }
}

enum DataSourceType { asset, exomedia, network, file, exomediaOffline }

class VideoPlayerController extends ValueNotifier<VideoPlayerValue> {
  /// Constructs a [VideoPlayerController] playing a video from an asset.
  ///
  /// The name of the asset is given by the [dataSource] argument and must not be
  /// null. The [package] argument must be non-null when the asset comes from a
  /// package and null otherwise.
  VideoPlayerController.asset(this.dataSource, {this.package})
      : dataSourceType = DataSourceType.asset,
        super(VideoPlayerValue(duration: null));

  /// Constructs a [VideoPlayerController] playing a video from obtained from
  /// the network.
  ///
  /// The URI for the video is given by the [dataSource] argument and must not be
  /// null.
  VideoPlayerController.network(this.dataSource)
      : dataSourceType = DataSourceType.network,
        package = null,
        super(VideoPlayerValue(duration: null));

  VideoPlayerController.exoplayerMeidaFrameWork(this.mediaContent,
      {bool isOffline = false})
      : dataSourceType = isOffline
            ? DataSourceType.exomediaOffline
            : DataSourceType.exomedia,
        package = null,
        super(VideoPlayerValue(duration: null));

  /// Constructs a [VideoPlayerController] playing a video from a file.
  ///
  /// This will load the file from the file-URI given by:
  /// `'file://${file.path}'`.
  VideoPlayerController.file(File file)
      : dataSource = 'file://${file.path}',
        dataSourceType = DataSourceType.file,
        package = null,
        super(VideoPlayerValue(duration: null));

  int _textureId;
  String dataSource;
  MediaContent mediaContent;

  /// Describes the type of data source this [VideoPlayerController]
  /// is constructed with.
  final DataSourceType dataSourceType;

  final String package;
  Timer _timer;
  bool _isDisposed = false;
  Completer<void> _creatingCompleter;
  StreamSubscription<dynamic> _eventSubscription;
  _VideoAppLifeCycleObserver _lifeCycleObserver;

  @visibleForTesting
  int get textureId => _textureId;

  Future<void> initialize() async {
    _lifeCycleObserver = _VideoAppLifeCycleObserver(this);
    _lifeCycleObserver.initialize();
    _creatingCompleter = Completer<void>();
    Map<dynamic, dynamic> dataSourceDescription;
    switch (dataSourceType) {
      case DataSourceType.asset:
        dataSourceDescription = <String, dynamic>{
          'asset': dataSource,
          'package': package
        };
        break;
      case DataSourceType.exomedia:
        dataSourceDescription = <String, dynamic>{
          'sourcetype': 'exomedia',
          'name': mediaContent.name,
          'uri': mediaContent.uri,
          'extension': mediaContent.extension,
          'drm_scheme': mediaContent.drm_scheme,
          'drm_license_url': mediaContent.drm_license_url,
          'ad_tag_uri': mediaContent.ad_tag_uri,
          'spherical_stereo_mode': mediaContent.spherical_stereo_mode,
          "subtitlesLink": mediaContent.subtitles,
          "localMediaDRMCallbackKey": mediaContent.localMediaDRMCallbackKey,
        };
        break;
      case DataSourceType.network:
        dataSourceDescription = <String, dynamic>{
          'uri': dataSource,
        };
        break;
      case DataSourceType.file:
        dataSourceDescription = <String, dynamic>{'uri': dataSource};
        break;

      case DataSourceType.exomediaOffline:
        dataSourceDescription = <String, dynamic>{
          'sourcetype': 'exomedia',
          'name': mediaContent.name,
          'uri': 'file://${File(mediaContent.uri).path}',
          'extension': mediaContent.extension,
          'drm_scheme': mediaContent.drm_scheme,
          'drm_license_url': mediaContent.drm_license_url,
          'ad_tag_uri': mediaContent.ad_tag_uri,
          'spherical_stereo_mode': mediaContent.spherical_stereo_mode,
          "subtitlesLink": mediaContent.subtitles,
          "localMediaDRMCallbackKey": mediaContent.localMediaDRMCallbackKey,
        };
        break;
    }

    final Map<dynamic, dynamic> response =
        await PlayerPlugin._channel.invokeMethod(
      'create',
      dataSourceDescription,
    );
    _textureId = response['textureId'];
    _creatingCompleter.complete(null);
    final Completer<void> initializingCompleter = Completer<void>();

    DurationRange toDurationRange(dynamic value) {
      final List<dynamic> pair = value;
      return DurationRange(
        Duration(milliseconds: pair[0]),
        Duration(milliseconds: pair[1]),
      );
    }

    void eventListener(dynamic event) {
      final Map<dynamic, dynamic> map = event;
      switch (map['event']) {
        case 'initialized':
          value = value.copyWith(
            duration: Duration(milliseconds: map['duration']),
            size: Size(map['width']?.toDouble() ?? 0.0,
                map['height']?.toDouble() ?? 0.0),
            resolutions: jsonDecode(map['resolutions']),
            subtitles: jsonDecode(map['subtitles']),
            audios: jsonDecode(map['audios']),
          );
          // print("Resolutons : ${map['resolutions']}");
          // print("Audios : ${map['audios']}");
          // print("Subtitles : ${map['subtitles']}");
          initializingCompleter.complete(null);
          _applyLooping();
          _applyVolume();
          _applyPlayPause();
          break;
        case 'completed':
          value = value.copyWith(isPlaying: false, position: value.duration);
          _timer?.cancel();
          break;
        case 'bufferingUpdate':
          final List<dynamic> values = map['values'];
          value = value.copyWith(
            buffered: values.map<DurationRange>(toDurationRange).toList(),
          );
          break;
        case 'bufferingStart':
          value = value.copyWith(isBuffering: true);
          break;
        case 'bufferingEnd':
          value = value.copyWith(isBuffering: false);
          break;
        case 'autoFormat':
          value = value.copyWith(autoFormat: map['autoFormat']);
      }
    }

    void errorListener(Object obj) {
      final PlatformException e = obj;
      value = VideoPlayerValue.erroneous(e.message);
      _timer?.cancel();
    }

    _eventSubscription = _eventChannelFor(_textureId)
        .receiveBroadcastStream()
        .listen(eventListener, onError: errorListener);
    return initializingCompleter.future;
  }

  EventChannel _eventChannelFor(int textureId) {
    return EventChannel('flutter.io/videoPlayer/videoEvents$textureId');
  }

  @override
  Future<void> dispose() async {
    if (_creatingCompleter != null) {
      await _creatingCompleter.future;
      if (!_isDisposed) {
        _isDisposed = true;
        _timer?.cancel();
        await _eventSubscription?.cancel();
        // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
        // https://github.com/flutter/flutter/issues/26431
        // ignore: strong_mode_implicit_dynamic_method
        await PlayerPlugin._channel.invokeMethod(
          'dispose',
          <String, dynamic>{'textureId': _textureId},
        );
      }
      _lifeCycleObserver.dispose();
    }
    _isDisposed = true;
    super.dispose();
  }

  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
    await _applyPlayPause();
  }

  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
    await _applyLooping();
  }

  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
    await _applyPlayPause();
  }

  Future<void> stop() async {
    value = value.copyWith(isPlaying: false);
    await _stop();
  }

  Future<void> _applyLooping() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    PlayerPlugin._channel.invokeMethod(
      'setLooping',
      <String, dynamic>{'textureId': _textureId, 'looping': value.isLooping},
    );
  }

  Future<void> _applyPlayPause() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    if (value.isPlaying) {
      // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
      // https://github.com/flutter/flutter/issues/26431
      // ignore: strong_mode_implicit_dynamic_method
      await PlayerPlugin._channel.invokeMethod(
        'play',
        <String, dynamic>{'textureId': _textureId},
      );
      _timer = Timer.periodic(
        const Duration(milliseconds: 500),
        (Timer timer) async {
          if (_isDisposed) {
            return;
          }
          final Duration newPosition = await position;
          if (_isDisposed) {
            return;
          }
          value = value.copyWith(position: newPosition);
        },
      );
    } else {
      _timer?.cancel();
      // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
      // https://github.com/flutter/flutter/issues/26431
      // ignore: strong_mode_implicit_dynamic_method
      await PlayerPlugin._channel.invokeMethod(
        'pause',
        <String, dynamic>{'textureId': _textureId},
      );
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    await PlayerPlugin._channel.invokeMethod(
      'stop',
      <String, dynamic>{'textureId': _textureId},
    );
  }

  Future<void> _applyVolume() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    await PlayerPlugin._channel.invokeMethod(
      'setVolume',
      <String, dynamic>{'textureId': _textureId, 'volume': value.volume},
    );
  }

  Future<void> _applySpeed() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    await PlayerPlugin._channel.invokeMethod(
      'speed',
      <String, dynamic>{'textureId': _textureId, 'speed': value.speed},
    );
  }

  Future<void> _applyResolution(int width, int height, int bitrate) async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    await PlayerPlugin._channel.invokeMethod(
      'resolution',
      <String, dynamic>{
        'textureId': _textureId,
        'width': width,
        'height': height,
        'bitrate': bitrate,
      },
    );
  }

  Future<void> _applyAudio(String code) async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    await PlayerPlugin._channel.invokeMethod(
      'audio',
      <String, dynamic>{'textureId': _textureId, 'code': code},
    );
  }

  /// The position in the current video.
  Future<Duration> get position async {
    if (_isDisposed) {
      return null;
    }
    return Duration(
      // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
      // https://github.com/flutter/flutter/issues/26431
      // ignore: strong_mode_implicit_dynamic_method
      milliseconds: await PlayerPlugin._channel.invokeMethod(
        'position',
        <String, dynamic>{'textureId': _textureId},
      ),
    );
  }

  Future<void> seekTo(Duration moment) async {
    if (_isDisposed) {
      return;
    }
    if (moment > value.duration) {
      moment = value.duration;
    } else if (moment < const Duration()) {
      moment = const Duration();
    }
    // TODO(amirh): remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    await PlayerPlugin._channel.invokeMethod('seekTo', <String, dynamic>{
      'textureId': _textureId,
      'location': moment.inMilliseconds,
    });
    value = value.copyWith(position: moment);
  }

  /// Sets the audio volume of [this].
  ///
  /// [volume] indicates a value between 0.0 (silent) and 1.0 (full volume) on a
  /// linear scale.
  Future<void> setVolume(double volume) async {
    value = value.copyWith(volume: volume.clamp(0.0, 1.0));
    await _applyVolume();
  }

  Future<void> setSpeed(double speed) async {
    value = value.copyWith(speed: speed.clamp(0.25, 2.0));
    await _applySpeed();
  }

  Future<void> setResolution(int width, int height, int bitrate) async {
    await _applyResolution(width, height, bitrate);
  }

  Future<void> setAudio(String code) async {
    await _applyAudio(code);
  }
}

class _VideoAppLifeCycleObserver extends Object with WidgetsBindingObserver {
  _VideoAppLifeCycleObserver(this._controller);

  bool _wasPlayingBeforePause = false;
  final VideoPlayerController _controller;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _wasPlayingBeforePause = _controller.value.isPlaying;
        _controller.pause();
        break;
      case AppLifecycleState.resumed:
        if (_wasPlayingBeforePause) {
          _controller.play();
        }
        break;
      default:
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

class VideoPlayer extends StatefulWidget {
  VideoPlayer(this.controller);

  final VideoPlayerController controller;

  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  _VideoPlayerState() {
    _listener = () {
      final int newTextureId = widget.controller.textureId;
      if (newTextureId != _textureId) {
        setState(() {
          _textureId = newTextureId;
        });
      }
    };
  }

  VoidCallback _listener;
  int _textureId;

  @override
  void initState() {
    super.initState();
    _textureId = widget.controller.textureId;
    // Need to listen for initialization events since the actual texture ID
    // becomes available after asynchronous initialization finishes.
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_listener);
    _textureId = widget.controller.textureId;
    widget.controller.addListener(_listener);
  }

  @override
  void deactivate() {
    widget.controller.removeListener(_listener);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return _textureId == null ? Container() : Texture(textureId: _textureId);
  }
}

class VideoProgressColors {
  VideoProgressColors({
    this.playedColor = const Color.fromRGBO(255, 0, 0, 0.7),
    this.bufferedColor = const Color.fromRGBO(50, 50, 200, 0.2),
    this.backgroundColor = const Color.fromRGBO(200, 200, 200, 0.5),
  });

  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;
}

class _VideoScrubber extends StatefulWidget {
  _VideoScrubber({
    @required this.child,
    @required this.controller,
  });

  final Widget child;
  final VideoPlayerController controller;

  @override
  _VideoScrubberState createState() => _VideoScrubberState();
}

class _VideoScrubberState extends State<_VideoScrubber> {
  bool _controllerWasPlaying = false;

  VideoPlayerController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    void seekToRelativePosition(Offset globalPosition) {
      final RenderBox box = context.findRenderObject();
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      final Duration position = controller.value.duration * relative;
      controller.seekTo(position);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: widget.child,
      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        _controllerWasPlaying = controller.value.isPlaying;
        if (_controllerWasPlaying) {
          controller.pause();
        }
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (_controllerWasPlaying) {
          controller.play();
        }
      },
      onTapDown: (TapDownDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
    );
  }
}


/// Displays the play/buffering status of the video controlled by [controller].
///
/// If [allowScrubbing] is true, this widget will detect taps and drags and
/// seek the video accordingly.
///
/// [padding] allows to specify some extra padding around the progress indicator
/// that will also detect the gestures.
class VideoProgressIndicator extends StatefulWidget {
  /// Construct an instance that displays the play/buffering status of the video
  /// controlled by [controller].
  ///
  /// Defaults will be used for everything except [controller] if they're not
  /// provided. [allowScrubbing] defaults to false, and [padding] will default
  /// to `top: 5.0`.
  VideoProgressIndicator(
      this.controller, {
        VideoProgressColors colors,
        this.allowScrubbing,
        this.padding = const EdgeInsets.only(top: 5.0),
      }) : colors = colors ?? VideoProgressColors();

  /// The [VideoPlayerController] that actually associates a video with this
  /// widget.
  final VideoPlayerController controller;

  /// The default colors used throughout the indicator.
  ///
  /// See [VideoProgressColors] for default values.
  final VideoProgressColors colors;

  /// When true, the widget will detect touch input and try to seek the video
  /// accordingly. The widget ignores such input when false.
  ///
  /// Defaults to false.
  final bool allowScrubbing;

  /// This allows for visual padding around the progress indicator that can
  /// still detect gestures via [allowScrubbing].
  ///
  /// Defaults to `top: 5.0`.
  final EdgeInsets padding;

  @override
  _VideoProgressIndicatorState createState() => _VideoProgressIndicatorState();
}

class _VideoProgressIndicatorState extends State<VideoProgressIndicator> {
  _VideoProgressIndicatorState() {
    listener = () {
      if (!mounted) {
        return;
      }
      setState(() {});
    };
  }

  VoidCallback listener;

  VideoPlayerController get controller => widget.controller;

  VideoProgressColors get colors => widget.colors;

  @override
  void initState() {
    super.initState();
    controller.addListener(listener);
  }

  @override
  void deactivate() {
    controller.removeListener(listener);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    Widget progressIndicator;
    if (controller.value.initialized) {
      final int duration = controller.value.duration.inMilliseconds;
      final int position = controller.value.position.inMilliseconds;

      int maxBuffering = 0;
      for (DurationRange range in controller.value.buffered) {
        final int end = range.end.inMilliseconds;
        if (end > maxBuffering) {
          maxBuffering = end;
        }
      }

      progressIndicator = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          LinearProgressIndicator(
            value: maxBuffering / duration,
            valueColor: AlwaysStoppedAnimation<Color>(colors.bufferedColor),
            backgroundColor: colors.backgroundColor,
          ),
          LinearProgressIndicator(
            value: position / duration,
            valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
            backgroundColor: Colors.transparent,
          ),
        ],
      );
    } else {
      progressIndicator = LinearProgressIndicator(
        value: null,
        valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
        backgroundColor: colors.backgroundColor,
      );
    }
    final Widget paddedProgressIndicator = Padding(
      padding: widget.padding,
      child: progressIndicator,
    );
    if (widget.allowScrubbing) {
      return _VideoScrubber(
        child: paddedProgressIndicator,
        controller: controller,
      );
    } else {
      return paddedProgressIndicator;
    }
  }
}

/// Widget for displaying closed captions on top of a video.
///
/// If [text] is null, this widget will not display anything.
///
/// If [textStyle] is supplied, it will be used to style the text in the closed
/// caption.
///
/// Note: in order to have closed captions, you need to specify a
/// [VideoPlayerController.closedCaptionFile].
///
/// Usage:
///
/// ```dart
/// Stack(children: <Widget>[
///   VideoPlayer(_controller),
///   ClosedCaption(text: _controller.value.caption.text),
/// ]),
/// ```
class ClosedCaption extends StatelessWidget {
  /// Creates a a new closed caption, designed to be used with
  /// [VideoPlayerValue.caption].
  ///
  /// If [text] is null, nothing will be displayed.
  const ClosedCaption({Key key, this.text, this.textStyle}) : super(key: key);

  /// The text that will be shown in the closed caption, or null if no caption
  /// should be shown.
  final String text;

  /// Specifies how the text in the closed caption should look.
  ///
  /// If null, defaults to [DefaultTextStyle.of(context).style] with size 36
  /// font colored white.
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final TextStyle effectiveTextStyle = textStyle ??
        DefaultTextStyle.of(context).style.copyWith(
          fontSize: 36.0,
          color: Colors.white,
        );

    if (text == null) {
      return SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: 24.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xB8000000),
            borderRadius: BorderRadius.circular(2.0),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(text, style: effectiveTextStyle),
          ),
        ),
      ),
    );
  }
}
