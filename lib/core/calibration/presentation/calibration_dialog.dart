import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/space_theme.dart';
import '../domain/device_calibration.dart';

/// Asistente interactivo de calibración óptica y antropométrica:
/// 1. Escala física de pantalla (`pixelsPerMm`) usando una tarjeta estándar ISO/IEC 7810 ID-1 (85.60 x 53.98 mm).
/// 2. Distancia interpupilar pre-vuelo del astronauta (`crewIpdMm`, 54–74 mm).
/// 3. Punto cercano basal pre-misión (`baselineNearPointCm`).
class CalibrationDialog extends ConsumerStatefulWidget {
  const CalibrationDialog({super.key});

  @override
  ConsumerState<CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends ConsumerState<CalibrationDialog> {
  late double _cardWidthPx;
  late double _crewIpdMm;
  late double _baselineNearPointCm;

  @override
  void initState() {
    super.initState();
    final cal = ref.read(deviceCalibrationProvider);
    _cardWidthPx = (cal.pixelsPerMm * DeviceCalibration.id1CardWidthMm)
        .clamp(180.0, 520.0);
    _crewIpdMm = cal.crewIpdMm;
    _baselineNearPointCm = cal.baselineNearPointCm;
  }

  @override
  Widget build(BuildContext context) {
    final pxPerMm = _cardWidthPx / DeviceCalibration.id1CardWidthMm;
    final cardHeightPx = pxPerMm * DeviceCalibration.id1CardHeightMm;

    return Dialog(
      backgroundColor: SpaceTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SpaceTheme.cyan, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten, color: SpaceTheme.cyan),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Calibración Óptica & Biométrica Basal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Ajusta la escala física de la pantalla (px/mm) y tus parámetros '
                'oftalmológicos de pre-vuelo para reducir el margen de error en pruebas SANS/SMS.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Divider(height: 24, color: Colors.white24),

              // 1. Escala física de pantalla (ID-1 Card)
              Text(
                '1. Escala de Pantalla: ${pxPerMm.toStringAsFixed(2)} px/mm',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SpaceTheme.cyan,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Coloca una credencial NASA o tarjeta estándar ID-1 (85.6 × 54.0 mm) '
                'sobre el recuadro e iguala su ancho con el deslizador.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: _cardWidthPx,
                  height: cardHeightPx,
                  decoration: BoxDecoration(
                    color: SpaceTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SpaceTheme.cyan, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ISO ID-1 (85.60 × 53.98 mm)\nCREW BADGE REFERENCE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.cyan,
                    ),
                  ),
                ),
              ),
              Slider(
                value: _cardWidthPx.clamp(180.0, 560.0),
                min: 180.0,
                max: 560.0,
                activeColor: SpaceTheme.cyan,
                label: '${_cardWidthPx.round()} px',
                onChanged: (v) => setState(() => _cardWidthPx = v),
              ),
              const SizedBox(height: 12),

              // 2. Distancia interpupilar (IPD)
              Text(
                '2. Distancia Interpupilar Pre-Vuelo (IPD): ${_crewIpdMm.toStringAsFixed(1)} mm',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SpaceTheme.cyan,
                ),
              ),
              const Text(
                'Elimina el error poblacional (±5.5%) en el cálculo trigonométrico de distancia ocular.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              Slider(
                value: _crewIpdMm,
                min: 54.0,
                max: 74.0,
                divisions: 40,
                activeColor: SpaceTheme.green,
                label: '${_crewIpdMm.toStringAsFixed(1)} mm',
                onChanged: (v) => setState(() => _crewIpdMm = v),
              ),
              const SizedBox(height: 12),

              // 3. Punto cercano basal
              Text(
                '3. Punto Cercano Basal (Pre-Misión): ${_baselineNearPointCm.toStringAsFixed(1)} cm',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SpaceTheme.cyan,
                ),
              ),
              const Text(
                'Permite separar la presbicia basal del desplazamiento hipermetrópico inducido por microgravedad (ΔD).',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              Slider(
                value: _baselineNearPointCm,
                min: 15.0,
                max: 50.0,
                divisions: 70,
                activeColor: Colors.amberAccent,
                label: '${_baselineNearPointCm.toStringAsFixed(1)} cm',
                onChanged: (v) => setState(() => _baselineNearPointCm = v),
              ),
              const SizedBox(height: 16),

              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _cardWidthPx =
                            6.3 * DeviceCalibration.id1CardWidthMm;
                        _crewIpdMm = 63.0;
                        _baselineNearPointCm = 25.0;
                      });
                    },
                    child: const Text('Restaurar Estándar'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SpaceTheme.cyan,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      final current = ref.read(deviceCalibrationProvider);
                      final updated = DeviceCalibration.fromId1CardWidthPx(
                        cardWidthLogicalPx: _cardWidthPx,
                        current: current,
                      ).copyWith(
                        crewIpdMm: _crewIpdMm,
                        baselineNearPointCm: _baselineNearPointCm,
                      );
                      await ref
                          .read(deviceCalibrationProvider.notifier)
                          .updateCalibration(updated);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar Calibración'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
