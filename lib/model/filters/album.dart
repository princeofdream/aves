import 'package:aves/model/filters/filters.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/utils/android_file_utils.dart';
import 'package:aves/widgets/common/identity/aves_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class AlbumFilter extends CollectionFilter {
  static const type = 'album';

  final String album;
  final String? displayName;

  @override
  List<Object?> get props => [album];

  const AlbumFilter(this.album, this.displayName);

  AlbumFilter.fromMap(Map<String, dynamic> json)
      : this(
          json['album'],
          json['uniqueName'],
        );

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'album': album,
        'uniqueName': displayName,
      };

  @override
  EntryFilter get test => (entry) => entry.directory == album;

  @override
  String get universalLabel => displayName ?? pContext.split(album).last;

  @override
  String getTooltip(BuildContext context) => album;

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool showGenericIcon = true}) {
    return IconUtils.getAlbumIcon(
          context: context,
          albumPath: album,
          size: size,
        ) ??
        (showGenericIcon ? Icon(AIcons.album, size: size) : null);
  }

  @override
  Future<Color> color(BuildContext context) {
    final colors = context.watch<AvesColorsData>();
    // do not use async/await and rely on `SynchronousFuture`
    // to prevent rebuilding of the `FutureBuilder` listening on this future
    final albumType = androidFileUtils.getAlbumType(album);
    switch (albumType) {
      case AlbumType.regular:
        break;
      case AlbumType.app:
        final appColor = colors.appColor(album);
        if (appColor != null) return appColor;
        break;
      case AlbumType.camera:
        return SynchronousFuture(colors.albumCamera);
      case AlbumType.download:
        return SynchronousFuture(colors.albumDownload);
      case AlbumType.screenRecordings:
        return SynchronousFuture(colors.albumScreenRecordings);
      case AlbumType.screenshots:
        return SynchronousFuture(colors.albumScreenshots);
      case AlbumType.videoCaptures:
        return SynchronousFuture(colors.albumVideoCaptures);
    }
    return super.color(context);
  }

  @override
  String get category => type;

  // key `album-{path}` is expected by test driver
  @override
  String get key => '$type-$album';
}
