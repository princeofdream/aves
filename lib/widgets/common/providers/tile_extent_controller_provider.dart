import 'package:aves/widgets/common/tile_extent_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class TileExtentControllerProvider extends StatelessWidget {
  final TileExtentController controller;
  final Widget child;

  const TileExtentControllerProvider({
    Key? key,
    required this.controller,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return LayoutBuilder(
          builder: (context, constraints) => ProxyProvider0<TileExtentController>(
            update: (context, __) => controller..setViewportSize(constraints.biggest),
            child: child,
          ),
        );
      },
    );
  }
}
