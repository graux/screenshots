import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'utils.dart' as utils;

class ImageMagick {
  static const _kThreshold = 0.76;
  final diffSuffix = '-diff';
//const kThreshold = 0.5;

  // singleton
  static final ImageMagick _imageMagick = ImageMagick._internal();
  factory ImageMagick() {
    return _imageMagick;
  }
  ImageMagick._internal();

  ///
  /// ImageMagick calls.
  ///
  Future convert(String command, Map options) async {
    List<String> cmdOptions;
    switch (command) {
      case 'overlay':
        cmdOptions = [
          options['screenshotPath'],
          options['statusbarPath'],
          '-gravity',
          'north',
          '-composite',
          options['screenshotPath'],
        ];
        break;
      case 'append':
        // convert -append screenshot_statusbar.png navbar.png final_screenshot.png
        cmdOptions = [
          '-append',
          options['screenshotPath'],
          options['screenshotNavbarPath'],
          options['screenshotPath'],
        ];
        break;
      case 'frame':
//  convert -size $size xc:skyblue \
//   \( "$frameFile" -resize $resize \) -gravity center -composite \
//   \( final_screenshot.png -resize $resize \) -gravity center -geometry -4-9 -composite \
//   framed.png

        cmdOptions = [
          '-size',
          options['size'],
          options['backgroundColor'],
          '(',
          options['screenshotPath'],
          '-resize',
          options['resize'],
          ')',
          '-gravity',
          'center',
          '-geometry',
          options['offset'],
          '-composite',
          '(',
          options['framePath'],
          '-resize',
          options['resize'],
          ')',
          '-gravity',
          'center',
          '-composite',
          options['screenshotPath']
        ];
        break;
      default:
        throw 'unknown command: $command';
    }
    cmd('convert', cmdOptions);
  }

  /// Checks if brightness of section of image exceeds a threshold
  bool thresholdExceeded(String imagePath, String crop,
      [double threshold = _kThreshold]) {
    //convert logo.png -crop $crop_size$offset +repage -colorspace gray -format "%[fx:(mean>$threshold)?1:0]" info:
    final result = cmd('convert', <String>[
      imagePath,
      '-crop',
      crop,
      '+repage',
      '-colorspace',
      'gray',
      '-format',
      '""%[fx:(mean>$threshold)?1:0]""',
      'info:'
    ]).replaceAll('"', '');
    return result == '1';
  }

  bool compare(String comparisonImage, String recordedImage) {
    final diffImage = getDiffName(comparisonImage);
    try {
      cmd('compare', <String>[
        '-metric',
        'mae',
        recordedImage,
        comparisonImage,
        diffImage
      ]);
    } catch (e) {
      return false;
    }
    // delete no-diff diff
    File(diffImage).deleteSync();
    return true;
  }

  String getDiffName(String comparisonImage) {
    final diffName = p.dirname(comparisonImage) +
        '/' +
        p.basenameWithoutExtension(comparisonImage) +
        diffSuffix +
        p.extension(comparisonImage);
    return diffName;
  }

  void deleteDiffs(String dirPath) {
    Directory(dirPath)
        .listSync()
        .where((fileSysEntity) =>
            p.basename(fileSysEntity.path).contains(diffSuffix))
        .forEach((diffImage) => File(diffImage.path).deleteSync());
  }

  /// ImageMagick command
  String cmd(String cmd, List cmdArgs) {
    // windows uses ImageMagick v7 or later
    if (Platform.isWindows) {
      return utils.cmd(
          'magick',
          [
            ...[cmd],
            ...cmdArgs
          ],
          '.',
          true);
    } else {
      return utils.cmd(cmd, cmdArgs, '.', true);
    }
  }
}
