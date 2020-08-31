import 'package:flutter/material.dart';
import 'package:player_plugin/player/screen/player.dart';

class PlayerContent {
  final String name;
  final String uri;
  final String extension;
  final String drm_scheme;
  final String drm_license_url;
  final String ad_tag_uri;
  final List<String> playlist;
  final String spherical_stereo_mode;
  final int playedLength;
  final List<SubtitleValues> subtitles;
  final LocalMediaDRMCallbackKey localMediaDRMCallbackKey;

  PlayerContent(
      {@required this.name,
      @required this.uri,
      this.extension = "",
      this.drm_scheme = 'widevine',
      this.drm_license_url = "",
      this.ad_tag_uri = "",
      this.spherical_stereo_mode = "",
      this.playlist = const [""],
      this.subtitles,
      this.playedLength = 0,
      this.localMediaDRMCallbackKey});

  @override
  String toString() {
    return 'Secured Content Name :$name \n'
        'Video Link :$uri \n'
        'Playlist :${playlist == null ? null : playlist.toString()}';
  }
}

class LocalMediaDRMCallbackKey{
  String key;
  String keyId;
  LocalMediaDRMCallbackKey({this.key, this.keyId});
}
