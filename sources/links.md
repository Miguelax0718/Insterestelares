# Enlaces y Recursos Externos

Utiliza este archivo para recopilar URLs útiles para el desarrollo de la aplicación.

## 🚀 NASA & Reto Oficial
- [NASA Space Apps Challenge](https://www.spaceappschallenge.org/)
- [NASA Technical Reports Server (NTRS)](https://ntrs.nasa.gov/)
- [NASA Human Research Roadmap](https://humanresearchroadmap.nasa.gov/)

## 🩺 Datos Biomédicos y Fisiología Espacial

### Biomarcadores de radiación (módulo `02_radiation`)

Fuentes usadas para estimar los valores de referencia de los biomarcadores. El detalle de cómo se usa cada dato está en `DB/real/inspiration4/README.md`.

**Datos reales de astronautas (NASA OSDR, misión Inspiration4, 2021)**
- [OSD-569](https://osdr.nasa.gov/bio/repo/data/studies/OSD-569): hemograma completo (linfocitos, neutrófilos, leucocitos). Línea base, variación entre visitas y cambio al regresar.
- [OSD-575](https://osdr.nasa.gov/bio/repo/data/studies/OSD-575): panel metabólico (creatinina sérica, glucosa, electrolitos) y citoquinas en suero, incluida IL-6.
- [OSD-656](https://osdr.nasa.gov/bio/repo/data/studies/OSD-656): proteínas inmunes en orina.

**Estrés oxidativo en orina (8-OHdG e isoprostanos)**
- Graille M. et al., 2020. *Urinary 8-OHdG as a Biomarker for Oxidative Stress: A Systematic Literature Review and Meta-Analysis*. Int J Mol Sci 21(11):3743. [doi:10.3390/ijms21113743](https://doi.org/10.3390/ijms21113743). Valor de referencia en adultos sanos: 3,9 ng/mg de creatinina (rango intercuartílico 3–5,5).
- Stein T.P. & Leskiw M.J., 2000. Estrés oxidativo en astronautas de Mir: el 8-OHdG no cambia en vuelo y los isoprostanos bajan ~20 %. [NTRS 20040141642](https://ntrs.nasa.gov/citations/20040141642)
- Smith S.M. & Zwart S.R., NASA 2006. ISS (n = 13): el 8-OHdG urinario es 22 % mayor después del vuelo. [NTRS 20060049121 (PDF)](https://ntrs.nasa.gov/api/citations/20060049121/downloads/20060049121.pdf)

**Límites de dosis**
- NASA, [NASA-STD-3001 Vol. 1 Rev. C](https://www.nasa.gov/wp-content/uploads/2023/11/nasa-std-3001-vol-1-rev-c-with-signature.pdf): límite de dosis efectiva de carrera de 600 mSv y límites no cancerígenos por órgano (tabla 4.8-1). Más detalle en `sources/medical/radiation_dosimetry.md`.

> [!WARNING]
> **Valores aproximados, sin fuente pública de astronautas.** Los siguientes valores del simulador son estimaciones del equipo y no salen de las fuentes de arriba:
> - Isoprostanos urinarios (valor absoluto de referencia)
> - MDA (malondialdehído)
> - Creatinina urinaria
> - PCR (proteína C reactiva)
> - Efecto de la dosis sobre los linfocitos (≈ −50 % por Gy)

### Signos vitales (módulo `01_general_health`, `DB/samples/vitals/`)
- Norsk P. et al., 2015. *Fluid shifts, vasodilatation and ambulatory blood pressure reduction during long duration spaceflight*. J Physiol 593(3):573–584. [PMC4324706](https://pmc.ncbi.nlm.nih.gov/articles/4324706/). Presión de 24 h −8/−9 mmHg en vuelo; la FC no cambia.
- Stahn A.C. et al., 2017. *Increased core body temperature in astronauts during long-duration space missions*. Sci Rep 7:16180. [PMC5701078](https://pmc.ncbi.nlm.nih.gov/articles/PMC5701078). Temperatura central +~1 °C en reposo, en ~2,5 meses.
- Meck J.V. et al., 2001. *Marked exacerbation of orthostatic intolerance after long- vs. short-duration spaceflight in veteran astronauts*. Psychosom Med 63(6):865–873. 5 de 6 astronautas con presíncope en la prueba de inclinación tras vuelos largos.
- Glucosa: NASA OSDR [OSD-575](https://osdr.nasa.gov/bio/repo/data/studies/OSD-575) (Inspiration4, panel metabólico).

### Microgravedad (módulo `03_microgravity`, `DB/samples/microgravity/`)
- LeBlanc A. et al., 2000. Pérdida ósea en cosmonautas de Mir: ~1 %/mes en columna y 1–1,5 %/mes en cadera. Cifra citada en resúmenes de la NASA; falta confirmar los valores por zona en el artículo original.
- Gopalakrishnan R., Genc K.O. et al., 2010. *Muscle volume, strength, endurance, and exercise loads during 6-month missions in space*. Aviat Space Environ Med 81(2):91–102. Pantorrilla −10 a −16 %, muslo −4 a −7 %.
- Tiempo de ejercicio en la ISS: ~600 min/semana (450–720) en 46 astronautas. npj Microgravity 2023, [doi:10.1038/s41526-023-00256-5](https://www.nature.com/articles/s41526-023-00256-5).

### Sueño (módulo `04_mental_health`, `DB/samples/sleep/`)
- Barger L.K. et al., 2014. *Prevalence of sleep deficiency and use of hypnotic drugs in astronauts before, during, and after spaceflight*. Lancet Neurol 13(9):904–912. [PMC4188436](https://pmc.ncbi.nlm.nih.gov/articles/PMC4188436). ISS: 6,09 ± 0,67 h en vuelo; medicación en el 11 % de las noches.

> [!WARNING]
> **Estimaciones del equipo (sin fuente pública de astronautas):** FC, presión y temperatura de partida de cada astronauta; SpO₂, frecuencia respiratoria y llenado capilar; despertares y ánimo matutino; DMO de partida en g/cm²; forma de la curva de atrofia; calorías por sesión.

## 💻 Herramientas y APIs
- *(Añade aquí enlaces a APIs de telemetría o librerías)*
