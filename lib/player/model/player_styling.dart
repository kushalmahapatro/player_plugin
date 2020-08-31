import 'package:flutter/material.dart';

class PlayerStyling {
  final PlayerProgressColors progressColors;
  final PlayerVolumeColors volumeColors;
  final PlayerLoaderConfig loaderConfig;

  PlayerStyling({this.progressColors, this.volumeColors, this.loaderConfig});
}

class PlayerProgressColors {
  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;
  final Color thumbColor;

  PlayerProgressColors({
    this.playedColor = Colors.green,
    this.bufferedColor = const Color.fromRGBO(0, 255, 0, 0.2),
    this.backgroundColor = Colors.white,
    this.thumbColor = Colors.green,
  });
}

class PlayerVolumeColors {
  final Color activeColor;
  final Color backgroundColor;

  PlayerVolumeColors(
      {this.activeColor = Colors.green, this.backgroundColor = Colors.white});
}

class PlayerLoaderConfig {
  final Color loaderColor;
  final String loadingText;

  PlayerLoaderConfig({this.loaderColor, this.loadingText});
}
