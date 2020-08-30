import 'dart:async';

import 'package:flutter/material.dart';
import 'package:player_plugin/player_plugin.dart';
import 'package:player_plugin/subtitle/model/style/subtitle_style.dart';
import 'package:player_plugin/subtitle/subtitle_controller.dart';
import 'package:player_plugin/subtitle/subtitle_text_view.dart';


// ignore: must_be_immutable
class Player extends StatefulWidget {
  Sample sampleVideo;
  bool showBackButton;
  ValueChanged<bool> onPlayerMaximise;
  final VideoPlayerController controller;
  ValueChanged<VideoPlayerController> onControllerInitialized;
  bool changingMedia;
  ValueChanged<bool> mediaChanged;
  ValueChanged<bool> videoCompleted;
  ValueChanged<int> lastPlaybackPosition;
  bool showResumePopup;

  Player(
      {Key key,
        this.sampleVideo,
        this.showBackButton,
        this.onPlayerMaximise,
        this.controller,
        this.onControllerInitialized,
        this.changingMedia,
        this.lastPlaybackPosition,
        this.videoCompleted,
        this.mediaChanged,
        this.showResumePopup = true})
      : super(key: key);

  @override
  PlayerState createState() => PlayerState();
}

class PlayerState extends State<Player> {
  VideoPlayerController controller;
  bool _isPlaying = false;
  bool _showController = false;
  bool _isControllerVisible;
  Timer _timer;
  double actualRatio, fullScreenRatio, aspectRatio, prevVolume = 0.0;
  bool _disposed = false, orientationChange = false, showResumePopup;

  List<PlaybackValues> playbackValues = [
    PlaybackValues("0.25x", 0.25),
    PlaybackValues("0.50x", 0.50),
    PlaybackValues("0.75x", 0.75),
    PlaybackValues("Normal", 1.00),
    PlaybackValues("1.25x", 1.25),
    PlaybackValues("1.50x", 1.50),
    PlaybackValues("1.75x", 1.75),
    PlaybackValues("2.00x", 2.00),
  ];
  List<ResolutionValues> resolutionValues = new List();
  List<AudioValues> audioValues = new List();
  List<SubtitleValues> subtitleValues = [
    SubtitleValues("", "OFF", SubtitleType.VTT),
  ];
  PlaybackValues selectedPlayback;
  ResolutionValues selectedResolution;
  AudioValues selectedAudio;
  SubtitleValues selectedSubtitle;
  int playerPosition, playerDuration;
  Timer _controlTimer;
  Stopwatch _stopwatch;
  int orientation = 1;
  SubtitleController _subtitleController;

  hideControls() {
    setState(() {
      _showController = false;
      _isControllerVisible = false;
    });
  }

  showControls({bool hide}) {
    bool toHide = hide ?? true;
    setState(() {
      _showController = true;
      _isControllerVisible = true;
      if (_timer != null) _timer.cancel();
    });
    if (toHide) {
      _timer = new Timer(const Duration(seconds: 4), () {
        hideControls();
      });
    }
  }

  // tracking status
  Future<void> _controllerListener() async {
    if (controller == null || _disposed) {
      return;
    }
    if (!controller.value.initialized) {
      return;
    }
    final bool isPlaying = controller.value.isPlaying;
    if (isPlaying != _isPlaying) {
      if (mounted)
        setState(() {
          _isPlaying = isPlaying;
          playerPosition = controller.value.position.inMilliseconds ?? 0;
          playerDuration = controller.value.duration.inMilliseconds ?? 0;
        });
      _stopwatch = new Stopwatch();
      _stopwatch.start();
      _controlTimer = new Timer.periodic(Duration(seconds: 1), (Timer timer) {
        if (playerPosition >= playerDuration) {
          if (mounted) {
            _controlTimer.cancel();
            widget.videoCompleted(true);
            setState(() {
              playerPosition = 0;
              controller.seekTo(Duration(milliseconds: 0));
              controller.pause();
              _stopwatch.stop();
              showControls();
            });
          }
        } else {
          if (mounted) {
            setState(() {
              if (_stopwatch.isRunning) {
                if (playerPosition <= playerDuration) {
                  if ((controller.value.position.inMilliseconds + 1000) <
                      playerDuration)
                    playerPosition =
                        controller.value.position.inMilliseconds + 1000;
                  else
                    playerPosition = (controller.value.position.inMilliseconds +
                        (playerDuration - playerPosition));
                  widget.lastPlaybackPosition(playerPosition);
                } else {
                  playerPosition = 0;
                  controller.seekTo(Duration(milliseconds: 0));
                  showControls();
                }
              }
            });
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(Player oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.changingMedia) {
      controller = null;
      _initialize();
    }
  }

  _initialize() {
    if (controller != null) {
      controller.pause();
      controller.removeListener(_controllerListener);
    } else {
      controller = widget.controller;
    }

    resolutionValues.clear();
    controller
      ..initialize().then((_) {
        if (controller.value.initialized) {
          if (controller.value.resolutions != null) {
            if (controller.value.resolutions.length > 0) {
              if (controller.value.resolutions[0] != "NO_VALUE") {
                resolutionValues.add(ResolutionValues(-1, -1, -1, "Auto"));
                for (int i = 0; i < controller.value.resolutions.length; i++) {
                  List<String> val = controller.value.resolutions[i].split(":");
                  List<String> res = val[0].split(" X ");
                  int width = int.parse(res[0]);
                  int height = int.parse(res[1].replaceAll("p", ""));
                  int bitrate = int.parse(val[1]);
                  resolutionValues
                      .add(ResolutionValues(width, height, bitrate, res[1]));
                  // print(widget.sampleVideo.playedLength);
                  if ((widget.sampleVideo.playedLength ?? 0) > 5000) {
                    setState(() {
                      if (widget.showResumePopup ?? false) {
                        hideControls();
                        showResumePopup = true;
                      } else {
                        playerPosition = widget.sampleVideo.playedLength;
                        controller
                            .seekTo(Duration(milliseconds: playerPosition));
                      }
                    });
                  } else {
                    playerPosition = widget.sampleVideo.playedLength ?? 0;
                    controller.seekTo(Duration(milliseconds: 0));
                  }
                }
                selectedResolution = resolutionValues[0];
              }
            }
          }
          if (controller.value.audios != null) {
            if (controller.value.audios.length > 0) {
              if (controller.value.audios[0] != "NO_VALUE") {
                for (int i = 0; i < controller.value.audios.length; i++) {
                  List<String> aud = controller.value.audios[i].split(":");
                  String name = aud[0].split(",")[0];
                  String code = aud[1];
                  if (code != "null") audioValues.add(AudioValues(name, code));
                }
                if (audioValues.length > 0) selectedAudio = audioValues[0];
              }
            }
          }
          if (subtitleValues.length > 1) {
            _subtitleController = SubtitleController(
                subtitleUrl: subtitleValues[0].url,
                showSubtitles: true,
                type: subtitleValues[0].type);
            selectedSubtitle = subtitleValues[0];
          }
          controller.play();
          controller.pause();
          showControls(hide: false);
          actualRatio = controller.value.aspectRatio;
          aspectRatio = actualRatio;
          widget.mediaChanged(false);
          setState(() {});
        }
      });
  }

  @override
  void initState() {
    super.initState();
    showResumePopup = false;
    controller = widget.controller;
    selectedPlayback = new PlaybackValues("Normal", 1.00);
    if(widget.sampleVideo.subtitles != null ){
      for (int i= 0 ; i< widget.sampleVideo.subtitles.length ; i++){
        subtitleValues.add(widget.sampleVideo.subtitles[i]);
      }
    }
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    controller.addListener(_controllerListener);
    double volume;
    //    Screen.keepOn(true);
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    fullScreenRatio = screenWidth / screenHeight;

    Widget volumeIcon(IconData icon) {
      return InkWell(
          child: Icon(
            icon,
            color: Colors.white,
          ),
          onTap: () {
            if (volume > 0) {
              setState(() {
                prevVolume = volume;
                controller.setVolume(0);
              });
            } else {
              setState(() {
                controller.setVolume(prevVolume);
              });
            }
            showControls();
          });
    }

    Widget progressBar(val) {
      if (val != null && val > 0.0 && val < 1.0) {
        return Slider(
          value: val,
          min: 0.0,
          max: 1.0,
          activeColor: Colors.green,
          inactiveColor: Colors.white,
          onChanged: (double value) {
            setState(() {
              if (!controller.value.initialized) {
                return;
              }
              playerPosition = (playerDuration * value).round();
              controller.seekTo(Duration(milliseconds: playerPosition));
              showControls();
            });
          },
          onChangeStart: (double value) {
            showControls(hide: false);
            _stopwatch.stop();
            if (!controller.value.initialized) {
              return;
            }
          },
          onChangeEnd: (double value) {
            if (!_stopwatch.isRunning) {
              _stopwatch.start();
            }
            showControls();
          },
        );
      } else {
        return Container(
          width: 0,
          height: 0,
        );
      }
    }

    void _settingModalBottomSheetPlayback(context) {
      showModalBottomSheet(
          isScrollControlled: true,
          context: context,
          builder: (BuildContext bc) {
            return Container(
                color: Colors.white,
                child: new Wrap(
                  children: playbackValues
                      .map((value) => InkWell(
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.check,
                              color: selectedPlayback.name == value.name
                                  ? Colors.black
                                  : Colors.transparent),
                          SizedBox(
                            width: 10,
                          ),
                          Text(value.name),
                        ],
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        selectedPlayback = value;
                      });
                      Navigator.pop(context);
                      controller.setSpeed(value.value);
                    },
                  ))
                      .toList(),
                ));
          });
    }

    void _settingModalBottomSheetResolutions(context) {
      showModalBottomSheet(
          isScrollControlled: true,
          context: context,
          builder: (BuildContext bc) {
            return Container(
                color: Colors.white,
                child: new Wrap(
                  children: resolutionValues.map((value) {
                    String res = "";
                    if (selectedResolution.value == "Auto" &&
                        value.value == "Auto") {
                      if (controller.value.autoFormat != "")
                        res = "${value.value} (${controller.value.autoFormat})";
                      else
                        res = value.value;
                    } else {
                      res = value.value;
                    }
                    return InkWell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5.0, vertical: 10),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.check,
                                color: selectedResolution.value == value.value
                                    ? Colors.black
                                    : Colors.transparent),
                            SizedBox(
                              width: 10,
                            ),
                            Text(res),
                          ],
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        controller.setResolution(
                            value.width, value.height, value.bitrate);
                        await Future.delayed(Duration(
                          milliseconds: 300,
                        ));
                        setState(() {
                          selectedResolution = value;
                        });
                      },
                    );
                  }).toList(),
                ));
          });
    }

    void _settingModalBottomSheetAudios(context) {
      showModalBottomSheet(
          isScrollControlled: true,
          context: context,
          builder: (BuildContext bc) {
            return Container(
                color: Colors.white,
                child: new Wrap(
                  children: audioValues
                      .map((value) => InkWell(
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.check,
                              color: selectedAudio.name == value.name
                                  ? Colors.black
                                  : Colors.transparent),
                          SizedBox(
                            width: 10,
                          ),
                          Text(value.name),
                        ],
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        selectedAudio = value;
                      });
                      Navigator.pop(context);
                      controller.setAudio(value.code);
                    },
                  ))
                      .toList(),
                ));
          });
    }

    void _settingModalBottomSheetSubtitles(context) {
      showModalBottomSheet(
          isScrollControlled: true,
          context: context,
          builder: (BuildContext bc) {
            return Container(
                color: Colors.white,
                child: new Wrap(
                  children: subtitleValues
                      .map((value) => InkWell(
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.check,
                              color: selectedSubtitle.name == value.name
                                  ? Colors.black
                                  : Colors.transparent),
                          SizedBox(
                            width: 10,
                          ),
                          Text(value.name),
                        ],
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        selectedSubtitle = value;
                        if (selectedSubtitle.name == "OFF")
                          _subtitleController = null;
                        else
                          _subtitleController = SubtitleController(
                              subtitleUrl: selectedSubtitle.url,
                              showSubtitles:
                              selectedSubtitle.name == "OFF"
                                  ? false
                                  : true,
                              type: selectedSubtitle.type);
                      });
                      Navigator.pop(context);
                    },
                  ))
                      .toList(),
                ));
          });
    }

    void _settingModalBottomSheet(context) {
      showModalBottomSheet(
          isScrollControlled: true,
          context: context,
          builder: (BuildContext bc) {
            String res = "";
            if (selectedResolution.value == "Auto") {
              if (controller.value.autoFormat != "")
                res =
                "${selectedResolution.value} (${controller.value.autoFormat})";
              else
                res = selectedResolution.value;
            } else {
              res = selectedResolution.value;
            }
            return Container(
              color: Colors.white,
              child: new Wrap(
                children: <Widget>[
                  InkWell(
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: 5, top: 10, bottom: 10, right: 5),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.play_circle_filled),
                          SizedBox(
                            width: 10,
                          ),
                          Text('Playback Speed : ${selectedPlayback.name}'),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _settingModalBottomSheetPlayback(context);
                    },
                  ),
                  if (selectedResolution != null &&
                      !widget.sampleVideo.uri
                          .contains("com.education.prepdesk"))
                    InkWell(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: 5, top: 10, bottom: 10, right: 5),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.high_quality),
                            SizedBox(
                              width: 10,
                            ),
                            Text('Quality : $res'),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _settingModalBottomSheetResolutions(context);
                      },
                    ),
                  if (selectedAudio != null)
                    InkWell(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: 5, top: 10, bottom: 10, right: 5),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.audiotrack),
                            SizedBox(
                              width: 10,
                            ),
                            Text('Audio : ${selectedAudio.name}'),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _settingModalBottomSheetAudios(context);
                      },
                    ),
                  if (selectedSubtitle != null)
                    InkWell(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: 5, top: 10, bottom: 10, right: 5),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.closed_caption),
                            SizedBox(
                              width: 10,
                            ),
                            Text('Captions : ${selectedSubtitle.name}'),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _settingModalBottomSheetSubtitles(context);
                      },
                    ),
                ],
              ),
            );
          });
    }

    Widget videoPlayerControls() {
      double val = playerPosition.toDouble() / playerDuration.toDouble();
      int maxBuffering = 0;
      for (DurationRange range in controller.value.buffered) {
        final int end = range.end.inMilliseconds;
        if (end > maxBuffering) {
          maxBuffering = end;
        }
      }
      volume = controller.value.volume;
      _isControllerVisible = true;
      return GestureDetector(
        child: Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (widget.showBackButton)
                          Align(
                              child: InkWell(
                                  onTap: onBackPressed,
                                  child: Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Icon(
                                        Icons.arrow_back_ios,
                                        color: Colors.white,
                                      ))),
                              alignment: Alignment.topLeft),
                        Flexible(
                          child: Align(
                            child: Text(
                              widget.sampleVideo.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(color: Colors.white),
                            ),
                            alignment: Alignment.center,
                          ),
                        ),
                        Align(
                            child: InkWell(
                                onTap: () {
                                  _settingModalBottomSheet(context);
                                },
                                child: Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: Icon(
                                      Icons.settings,
                                      color: Colors.white,
                                    ))),
                            alignment: Alignment.topRight),
                      ],
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    ),
                    Expanded(
                        child: Stack(
                          children: <Widget>[
                            Align(
                                alignment: Alignment.center,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Wrap(
                                      spacing: 30.0,
                                      children: <Widget>[
                                        InkWell(
                                          child: Container(
                                            child: Center(
                                                child: Icon(
                                                  Icons.replay_10,
                                                  color: Colors.white,
                                                  size: 40.0,
                                                )),
                                            height: 70.0,
                                          ),
                                          onTap: () {
                                            setState(() {
                                              if ((playerPosition - 10000) > 0) {
                                                playerPosition = playerPosition - 10000;
                                              } else {
                                                playerPosition =
                                                    (playerPosition) - playerPosition;
                                              }
                                              controller.seekTo(Duration(
                                                  milliseconds: playerPosition));
                                            });
                                            showControls();
                                          },
                                        ),
                                        InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (controller.value.isPlaying) {
                                                  controller.pause();
                                                  _stopwatch.stop();
                                                  showControls(hide: false);
                                                } else {
                                                  controller.play();
                                                  _stopwatch.start();
                                                  hideControls();
                                                }
                                              });
                                            },
                                            child: Icon(
                                              controller.value.isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 70.0,
                                            )),
                                        InkWell(
                                          child: Container(
                                            child: Center(
                                                child: Icon(
                                                  Icons.forward_10,
                                                  color: Colors.white,
                                                  size: 40.0,
                                                )),
                                            height: 70.0,
                                          ),
                                          onTap: () {
                                            setState(() {
                                              if ((playerPosition + 10000) <
                                                  playerDuration) {
                                                playerPosition = playerPosition + 10000;
                                              } else {
                                                playerPosition = (playerPosition) +
                                                    (playerDuration - playerPosition);
                                              }
                                              controller.seekTo(Duration(
                                                  milliseconds: playerPosition));
                                            });
                                            showControls();
                                          },
                                        )
                                      ],
                                    )
                                  ],
                                )),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              top: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Expanded(
                                      child: RotatedBox(
                                          quarterTurns: -1,
                                          child: Slider(
                                            value: controller.value.volume,
                                            min: 0.0,
                                            max: 1.0,
                                            activeColor: Colors.green,
                                            inactiveColor: Colors.white,
                                            onChanged: (double value) {
                                              setState(() {
                                                if (!controller.value.initialized) {
                                                  return;
                                                }
                                                controller.setVolume(value);
                                                showControls();
                                              });
                                            },
                                            onChangeStart: (double value) {
                                              showControls(hide: false);
                                              if (!controller.value.initialized) {
                                                return;
                                              }
                                            },
                                            onChangeEnd: (double value) {
                                              setState(() {
                                                volume = value;
                                              });
                                              showControls();
                                            },
                                          ))),
                                  if (volume >= 0.6) volumeIcon(Icons.volume_up),
                                  if (volume >= 0.3 && volume < 0.6)
                                    volumeIcon(Icons.volume_down),
                                  if (volume < 0.3 && volume >= 0.01)
                                    volumeIcon(Icons.volume_mute),
                                  if (volume < 0.01) volumeIcon(Icons.volume_off),
                                ],
                              ),
                            )
                          ],
                        )),
                    Align(
                      child: Padding(
                          padding: EdgeInsets.only(left: 20.0, right: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                getTime(playerPosition),
                                style: TextStyle(color: Colors.white),
                              ),
                              Expanded(child: progressBar(val)),
                              Text(
                                getTime(playerDuration),
                                style: TextStyle(color: Colors.white),
                              ),
                              InkWell(
                                  onTap: () {
                                    if (orientation == 1) {
                                      widget.onPlayerMaximise(true);
                                      setState(() {
                                        orientation = 2;
                                      });
                                    } else {
                                      widget.onPlayerMaximise(false);
                                      setState(() {
                                        orientation = 1;
                                      });
                                    }
                                  },
                                  child: Padding(
                                      padding: EdgeInsets.only(left: 10.0),
                                      child: Icon(
                                        orientation == 2
                                            ? Icons.fullscreen_exit
                                            : Icons.fullscreen,
                                        color: Colors.white,
                                      )))
                            ],
                          )),
                      alignment: Alignment.bottomCenter,
                    )
                  ],
                ))),
        onTap: () {
          if (_showController) {
            hideControls();
          }
        },
        onDoubleTap: () {
          if (orientation != 1) if (aspectRatio == actualRatio) {
            setState(() {
              aspectRatio = fullScreenRatio;
            });
          } else if (aspectRatio == fullScreenRatio) {
            setState(() {
              aspectRatio = actualRatio;
            });
          }
        },
      );
    }

    return controller.value.initialized
        ? AspectRatio(
      aspectRatio: orientation == 1 ? 4 / 3 : screenWidth / screenHeight,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            child: Container(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                      aspectRatio: (aspectRatio ?? 4 / 3) > 0.0
                          ? (aspectRatio ?? 4 / 3)
                          : 4 / 3,
                      child: VideoPlayer(controller)),
                )),
            onTap: () {
              setState(() {
                if (!_showController) {
                  showControls();
                }
              });
            },
            onDoubleTap: () {
              if (orientation != 1) if (aspectRatio == actualRatio) {
                setState(() {
                  aspectRatio = fullScreenRatio;
                });
              } else if (aspectRatio == fullScreenRatio) {
                setState(() {
                  aspectRatio = actualRatio;
                });
              }
            },
          ),
          controller.value.isBuffering
              ? CircularProgressIndicator()
              : new Container(),
          if (!showResumePopup && _showController) videoPlayerControls(),
          if (_subtitleController != null)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: SubtitleTextView(
                subtitleController: _subtitleController,
                videoPlayerController: controller,
                subtitleStyle: SubtitleStyle(
                    fontSize: 16,
                    textColor: Colors.white,
                    hasBorder: true),
              ),
            ),
          if (showResumePopup)
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                    color: Colors.black.withOpacity(0.8),
                    padding: EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          "Do you want to resume the playback where you left from?",
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 20,
                            ),
                            Flexible(
                                flex: 1,
                                child: InkWell(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 10),
                                    width: double.maxFinite,
                                    color: Colors.red,
                                    child: Center(child: Text("No")),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      showResumePopup = false;
                                      playerPosition = 0;
                                      controller.seekTo(
                                          Duration(milliseconds: 0));
                                      showControls();
                                      controller.play();
                                    });
                                  },
                                )),
                            SizedBox(
                              width: 20,
                            ),
                            Flexible(
                                flex: 1,
                                child: InkWell(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 10),
                                    width: double.maxFinite,
                                    color: Colors.white,
                                    child: Center(child: Text("Yes")),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      showResumePopup = false;
                                      playerPosition =
                                          widget.sampleVideo.playedLength;
                                      controller.seekTo(Duration(
                                          milliseconds: playerPosition));
                                      showControls();
                                      controller.play();
                                    });
                                  },
                                )),
                            SizedBox(
                              width: 20,
                            ),
                          ],
                        )
                      ],
                    ))),
        ],
      ),
    )
        : AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        // width: screenWidth,
        // height: screenHeight / (4 / 3),
        color: Colors.black,
        child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(),
                Padding(
                    padding: EdgeInsets.only(left: 10.0),
                    child: Text(
                      "Loading...",
                      style: TextStyle(color: Colors.white, fontSize: 20.0),
                    ))
              ],
            )),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    if (_timer != null) _timer.cancel();
    if (_controlTimer != null) _controlTimer.cancel();
    if (_stopwatch != null) _stopwatch.stop();
    super.dispose();
  }

  String getTime(int milis) {
    Duration position = Duration(milliseconds: milis);
    String twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    String twoDigitMinutes = twoDigits(position.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(position.inSeconds.remainder(60));
    String time;
    if (twoDigits(position.inHours) == "00") {
      time = "$twoDigitMinutes:$twoDigitSeconds";
    } else {
      time = "${twoDigits(position.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return time;
  }

  Future<bool> onBackPressed() {
    if (orientation == 1) {
      Sample sample = new Sample(
          name: widget.sampleVideo.name,
          ad_tag_uri: widget.sampleVideo.ad_tag_uri,
          drm_license_url: widget.sampleVideo.drm_license_url,
          drm_scheme: widget.sampleVideo.drm_scheme,
          extension: widget.sampleVideo.extension,
          playedLength: playerPosition,
          playlist: widget.sampleVideo.playlist,
          spherical_stereo_mode: widget.sampleVideo.spherical_stereo_mode,
          uri: widget.sampleVideo.uri);
      Navigator.pop(context, sample);
      if (_timer != null) _timer.cancel();
      if (_controlTimer != null) _controlTimer.cancel();
      _stopwatch.stop();
    } else {
      widget.onPlayerMaximise(false);
      setState(() {
        setState(() {
          orientation = 1;
        });
      });
    }
    return Future.value(false);
  }
}

class PlaybackValues {
  String name;
  double value;

  PlaybackValues(this.name, this.value);
}

class ResolutionValues {
  int width;
  int height;
  int bitrate;
  String value;

  ResolutionValues(this.width, this.height, this.bitrate, this.value);
}

class AudioValues {
  String name;
  String code;

  AudioValues(this.name, this.code);
}

class SubtitleValues {
  String url;
  String name;
  SubtitleType type;

  SubtitleValues(this.url, this.name, this.type);
}

class Sample {
  final String name;
  final String uri;
  final String extension;
  final String drm_scheme;
  final String drm_license_url;
  final String ad_tag_uri;
  final List<String> playlist;
  final List<SubtitleValues> subtitles;
  final String spherical_stereo_mode;
  final int playedLength;
  final String key;
  final String keyId;

  factory Sample.fromJson(Map<String, dynamic> parsedJson) {
    List<String> playlistfiles = null;
    List<SubtitleValues> subtitlesFiles = null;
    if (parsedJson['playlist'] != null) {
      playlistfiles = parsePlayLists(parsedJson['playlist']);
    }

    if (parsedJson['subtitles'] != null) {
      subtitlesFiles = parseSubtitles(parsedJson['subtitles']);
    }

    return Sample(
        name: parsedJson['name'],
        uri: parsedJson['uri'],
        extension: parsedJson['extension'],
        drm_scheme: parsedJson['drm_scheme'],
        drm_license_url: parsedJson['drm_license_url'],
        ad_tag_uri: parsedJson['ad_tag_uri'],
        spherical_stereo_mode: parsedJson['spherical_stereo_mode'],
        playlist: playlistfiles,
        subtitles: subtitlesFiles ,
        playedLength: 0,
        key: parsedJson['key'],
        keyId: parsedJson['keyId']);
  }

  static List<Sample> parseSampleLists(parsedresponseBody) {
    return parsedresponseBody
        .map<Sample>((json) => Sample.fromJson(json))
        .toList();
  }

  Sample(
      {@required this.name,
        @required this.uri,
        this.extension  = "",
        this.drm_scheme = 'widevine',
        this.drm_license_url = "",
        this.ad_tag_uri = "",
        this.spherical_stereo_mode = "",
        this.playlist = const [""],
        this.subtitles,
        this.playedLength= 0,
        this.key,
        this.keyId});

  @override
  String toString() {
    return 'Video Name :$name \n'
        'Video Link :$uri \n'
        'Playlist :${playlist == null ? null : playlist.toString()}';
  }

  static List<String> parsePlayLists(parsedresponseBody) {
    return parsedresponseBody
        .map<String>((json) => playListfromJson(json))
        .toList();
  }

  static List<SubtitleValues> parseSubtitles (body){
    return body.map<SubtitleValues>((value) => value).toList();
  }

  static String playListfromJson(json) {
    return json['uri'];
  }
}
