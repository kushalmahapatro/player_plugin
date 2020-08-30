import 'package:flutter/material.dart';

class MediaContent {
  final String name;
  final String uri;
  final String extension;
  final String drm_scheme;
  final String drm_license_url;
  final String ad_tag_uri;
  final List<String> playlist;
  final String spherical_stereo_mode;
  final List<String> subtitles;
  final String localMediaDRMCallbackKey;

  MediaContent(
      {@required this.name,
      this.uri,
      this.extension,
      this.drm_scheme,
      this.drm_license_url,
      this.ad_tag_uri,
      this.spherical_stereo_mode,
      this.playlist,
      this.subtitles,
      this.localMediaDRMCallbackKey});

  @override
  String toString() {
    return 'Secured Content Name :$name \n'
        'Video Link :$uri \n'
        'Local DRM callback Key : $localMediaDRMCallbackKey \n'
        'Playlist :${playlist == null ? null : playlist.toString()}';
  }
}
