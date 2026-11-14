# Radiation dosimetry

This offline prototype loads a deterministic 180-day mission for four fictitious
crewmembers from `DB/samples/radiation/`. All measurements are synthetic.

## Implemented

- Career effective dose: prior career dose plus mission daily doses, compared
  with the 600 mSv reference. The SPE component is already in each daily dose.
- Organ dose use: rolling 30-day and 365-day windows, and mission dose compared
  with applicable career organ limits. `highestFractionUsed` exposes the largest
  fraction for integration with the biological layer.
- SPE status: active, inactive, or unknown, using the explicit weather flag.
- Local asset loading, schema validation, crew selection, and mission-day selection.
- Cumulative career-dose chart: day zero contains the prior career dose; the curve
  includes only records through the selected day and a 600 mSv reference line.
  Values above the reference remain visible. No SPE dose is added a second time.
- Manual shelter drill during an SPE when the selected record is outside the
  shelter. Start/resume, pause, mark arrival, and reset controls are available.
  A sheltered crewmember receives an explanatory message instead of a drill.

## Shelter drill behavior

The default two-hour duration is a demonstration setting, not a clinically
validated deadline, safe exposure window, or NASA requirement. Viewing a
historical/simulated SPE day never starts a timer automatically. The timer uses
an absolute deadline so delayed callbacks or background suspension do not extend
the drill; it stops at zero without claiming that the crewmember is safe.
Changing crew/day or leaving the screen discards the drill. There is no persistent
incident log, remote notification, or operational emergency protocol in this demo.

## Structure

- `data/`: generator, CSV parser, and local asset repository.
- `models/`: crew profiles, daily organ doses, and space-weather readings.
- `providers/`: career/organ calculations, SPE detection, combined daily summary,
  cumulative history, and Riverpod loading.
- `widgets/`: cumulative chart and shelter drill.
- `presentation/`: radiation screen.
- `test/features/02_radiation/`: focused history and display/drill regression tests.

## Verification

Run from the repository root:

```sh
flutter test test/features/02_radiation/radiation_display_test.dart
flutter build web --no-web-resources-cdn
```

The focused tests cover history filtering/order, prior career dose, SPE counting,
duplicate and missing days, invalid prior dose, narrow/wide chart layouts, a dose
above the reference, deadline-based countdown, pause/resume, expiry, arrival,
reset, and disposal. They do not constitute validation of the entire dose engine.

## Integration and remaining scope

`RadiationDailySummary` provides the crew ID, mission day, career total, remaining
budget, organ-window comparisons, SPE status, and that day's SPE component.
The exact exchange schema still needs agreement with the biomarker contributor.
The combined dose/biology matrix, recommendations, organ traffic lights, and
clickable body remain shared work. Comprehensive core-engine tests are pending.

Prior organ-specific career history and separate CNS heavy-ion measurements are
not available in this dataset and are not inferred from effective dose.

Reference values and their units are documented in
`sources/medical/radiation_dosimetry.md`; the sample schema and limitations are in
`DB/samples/radiation/README.md`. The 250 mSv SPE design reference must not be
used as a standalone event detector or an individual clinical threshold.
