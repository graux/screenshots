import 'dart:io';

import 'package:args/args.dart';
import 'package:screenshots/src/context_runner.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/image_processor.dart';
import 'package:screenshots/src/resources.dart';
import 'package:screenshots/src/screens.dart';

import '../src/common.dart';

const usage = 'usage: frame [-h] [-s <screenshot file> -d <device name>]';
const sampleUsage = 'sample usage: frame -s screenshot.png -d \'Nexus 6P\'';

const kFrameTestTmpDir = '/tmp/frame_test';
const kRunMode = RunMode.normal;

void main(List<String> arguments) async {
  late ArgResults argResults;

  const screenshotArg = 'screenshot';
  const deviceArg = 'device';
  const helpArg = 'help';
  final argParser = ArgParser(allowTrailingOptions: false)
    ..addOption(screenshotArg,
        abbr: 's',
        defaultsTo: 'screenshot.png',
        help: 'Path to screenshot file.',
        valueHelp: 'screenshot.png')
    ..addOption(deviceArg,
        abbr: 'd', help: 'Device name.', valueHelp: 'device name')
    ..addFlag(helpArg,
        abbr: 'h', help: 'Display this help information.', negatable: false);
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(argParser, e.toString());
  }
  // show help
  if (argResults[helpArg] as bool ||
      !(argResults.wasParsed(screenshotArg) &&
          argResults.wasParsed(deviceArg))) {
    _showUsage(argParser);
    exit(0);
  }

  // validate args
  // ignore: avoid_slow_async_io
  if (!await File(argResults[screenshotArg].toString()).exists()) {
    _handleError(argParser, 'File not found: ${argResults[screenshotArg]}');
  }

  final screenshotPath = argResults[screenshotArg].toString();
  final deviceName = argResults[deviceArg].toString();

  await runFrame(screenshotPath, deviceName);
}

Future<void> runFrame(String screenshotPath, String deviceName) async {
  final screens = Screens();
  await screens.init();
  final screen = screens.getScreen(deviceName);
  if (screen == null) {
    print('Error: screen not found for \'$deviceName\'');
    exit(1);
  }
  final deviceType = screens.getDeviceType(deviceName);

  if (deviceType == null) {
    print('Error: deviceType not found for \'$deviceName\'');
    exit(1);
  }

  clearDirectory(kFrameTestTmpDir);

  const framedScreenshotPath = '$kFrameTestTmpDir/framed_screenshot.png';
  await File(screenshotPath).copy(framedScreenshotPath);

  final screenResources = screen['resources'] as Map<String, dynamic>;
  await unpackImages(screenResources, kFrameTestTmpDir);

  await runInContext<void>(() async {
    // overlay status bar
    await ImageProcessor.overlay(
        kFrameTestTmpDir, screenResources, framedScreenshotPath);

    // append navigation bar (if android)
    if (deviceType == DeviceType.android) {
      await ImageProcessor.append(
          kFrameTestTmpDir, screenResources, framedScreenshotPath);
    }

    // frame
    await ImageProcessor.frame(
        kFrameTestTmpDir, screen, framedScreenshotPath, deviceType, kRunMode);
  });
  print('Framed screenshot created: $framedScreenshotPath');
}

void _handleError(ArgParser argParser, String msg) {
  stderr.writeln(msg);
  _showUsage(argParser);
}

void _showUsage(ArgParser argParser) {
  print(usage);
  print('\n$sampleUsage\n');
  print(argParser.usage);
  exit(2);
}
