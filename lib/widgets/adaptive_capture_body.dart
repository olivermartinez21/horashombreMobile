import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// En vertical: instrucciones, vista previa y controles en columna.
/// En horizontal: la vista previa ocupa la izquierda y los controles
/// la derecha, para que el recuadro de la cámara use la altura de la pantalla.
class AdaptiveCaptureBody extends StatelessWidget {
  const AdaptiveCaptureBody({
    super.key,
    required this.preview,
    required this.controls,
    this.banner,
  });

  final Widget preview;
  final Widget controls;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (!landscape) {
      return Column(
        children: [
          ?banner,
          Expanded(child: preview),
          controls,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
            child: Center(child: preview),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (banner != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(child: banner),
                    ),
                  )
                else
                  const Spacer(),
                controls,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// En horizontal recorta la vista previa para que llene el panel izquierdo.
class CameraPreviewFrame extends StatelessWidget {
  const CameraPreviewFrame({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = CameraPreview(controller);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (!landscape) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: preview,
        ),
      );
    }

    final ratio = controller.value.aspectRatio <= 0
        ? 3 / 2
        : controller.value.aspectRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounds = constraints.biggest;
          var width = bounds.width;
          var height = width / ratio;
          if (height < bounds.height) {
            height = bounds.height;
            width = height * ratio;
          }
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              minWidth: width,
              maxWidth: width,
              minHeight: height,
              maxHeight: height,
              child: SizedBox(
                width: width,
                height: height,
                child: preview,
              ),
            ),
          );
        },
      ),
    );
  }
}
