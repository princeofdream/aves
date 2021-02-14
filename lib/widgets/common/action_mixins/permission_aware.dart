import 'package:aves/model/entry.dart';
import 'package:aves/services/android_file_service.dart';
import 'package:aves/utils/android_file_utils.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:flutter/material.dart';

mixin PermissionAwareMixin {
  Future<bool> checkStoragePermission(BuildContext context, Set<AvesEntry> entries) {
    return checkStoragePermissionForAlbums(context, entries.where((e) => e.path != null).map((e) => e.directory).toSet());
  }

  Future<bool> checkStoragePermissionForAlbums(BuildContext context, Set<String> albumPaths) async {
    while (true) {
      final dirs = await AndroidFileService.getInaccessibleDirectories(albumPaths);
      if (dirs == null) return false;
      if (dirs.isEmpty) return true;

      final dir = dirs.first;
      final volumePath = dir['volumePath'] as String;
      final relativeDir = dir['relativeDir'] as String;

      final volume = androidFileUtils.storageVolumes.firstWhere((volume) => volume.path == volumePath, orElse: () => null);
      final volumeDescription = volume?.description ?? volumePath;
      final dirDisplayName = relativeDir.isEmpty ? 'root' : '“$relativeDir”';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AvesDialog(
            context: context,
            title: 'Storage Volume Access',
            content: Text('Please select the $dirDisplayName directory of “$volumeDescription” in the next screen, so that this app can access it and complete your request.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'.toUpperCase()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('OK'.toUpperCase()),
              ),
            ],
          );
        },
      );
      // abort if the user cancels in Flutter
      if (confirmed == null || !confirmed) return false;

      final granted = await AndroidFileService.requestVolumeAccess(volumePath);
      if (!granted) {
        // abort if the user denies access from the native dialog
        return false;
      }
    }
  }
}
