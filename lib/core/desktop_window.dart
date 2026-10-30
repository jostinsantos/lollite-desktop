import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Gestión Windows: cerrar a bandeja / iniciar con Windows.
class DesktopWindowController with WindowListener {
  DesktopWindowController._();
  static final DesktopWindowController instance = DesktopWindowController._();

  bool _closeToTray = true;
  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    if (kIsWeb || !Platform.isWindows) return;
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    _closeToTray = prefs.getBool('close_to_tray') ?? true;
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
  }

  Future<void> reloadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _closeToTray = prefs.getBool('close_to_tray') ?? true;
  }

  Future<void> setCloseToTray(bool value) async {
    _closeToTray = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('close_to_tray', value);
  }

  Future<void> setStartWithWindows(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('start_with_windows', enabled);
    if (!Platform.isWindows) return;
    try {
      final exe = Platform.resolvedExecutable;
      if (enabled) {
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          'LolLiteDesktop',
          '/t',
          'REG_SZ',
          '/d',
          '"$exe"',
          '/f',
        ]);
      } else {
        await Process.run('reg', [
          'delete',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          'LolLiteDesktop',
          '/f',
        ]);
      }
    } catch (e) {
      debugPrint('[DesktopWindow] startup registry: $e');
    }
  }

  @override
  void onWindowClose() async {
    if (_closeToTray) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  Future<void> showFromTray() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
