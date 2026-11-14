// Entrada de la misión de ejemplo, compartida por el generador de CSV y el
// repositorio mock. No importa dart:io, así que también sirve en Chrome.

/// Entrada de dosis de EJEMPLO (no medida): una tormenta solar el día 95 de
/// una misión de 180 días. Dos astronautas fuera del refugio y dos dentro.
/// Cuando la dosimetría de María esté lista, se reemplaza por sus valores.
const int exampleSpeDay = 95;
const Map<String, double> exampleSpeDoseMsv = {
  'AST-01': 50,
  'AST-02': 10,
  'AST-03': 50,
  'AST-04': 10,
  'AST-05': 50,
};
const Set<String> exampleSheltered = {'AST-02', 'AST-04'};
