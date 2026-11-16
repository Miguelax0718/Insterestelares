# Referencias, Estándares y Recursos Externos (`APOLO / AstraMed`)

> **Nota de Seguridad:** Este índice contiene únicamente documentación pública, estándares oficiales, literatura científica y librerías open-source utilizadas en el proyecto. **No** incluye claves de API, tokens, credenciales ni endpoints privados.

---

## 1. 🚀 NASA, Estándares Operacionales y Reto Oficial

- **[NASA Space Apps Challenge](https://www.spaceappschallenge.org/)** — Portal oficial de la competencia global (*Health Monitoring Software for Astronauts on Space Missions*).
- **[NASA Human Research Program (HRP) — 5 Hazards of Human Spaceflight](https://www.nasa.gov/hrp/5-hazards-of-human-spaceflight/)** — Marco de los 5 riesgos del vuelo espacial humano: Radiación espacial, Aislamiento y confinamiento, Distancia de la Tierra, Campos gravitatorios y Entornos cerrados hostiles.
- **[NASA Human Research Roadmap (HRR)](https://humanresearchroadmap.nasa.gov/)** — Base de datos oficial de riesgos, brechas (*gaps*) y contramedidas para la salud humana en el espacio.
- **[NASA Technical Reports Server (NTRS)](https://ntrs.nasa.gov/)** — Repositorio público de reportes técnicos e investigaciones biomédicas y de ingeniería de la NASA.
- **[NASA-STD-3001 Volume 1, Revision C (2023) — Spaceflight Human-System Standard: Crew Health](https://www.nasa.gov/wp-content/uploads/2023/11/nasa-std-3001-vol-1-rev-c-with-signature.pdf)** — Estándar oficial de límites de dosis de radiación de carrera (600 mSv universal), umbrales de signos vitales, protocolos de ejercicio y atención médica de la tripulación.
- **[NASA-STD-3001 Volume 1 & 2 — Human Performance Reference (V1 4024)](https://www.nasa.gov/reference/4-0-human-performance/)** — Directrices de evaluación cognitiva, fatiga, carga de trabajo y rendimiento humano.
- **[NASA OCHMO-TB-020 — Design for Ionizing Radiation Protection (Rev. G, 2023)](https://www.nasa.gov/wp-content/uploads/2023/12/ochmo-tb-020-radiation-protection.pdf)** — Boletín técnico de la Oficina del Director Médico y de Salud sobre blindaje, principio ALARA y protección radiológica en LEO, órbita cislunar y espacio profundo.
- **[NASA OCHMO-TB-031 — Exercise Overview (2023)](https://www.nasa.gov/wp-content/uploads/2023/12/ochmo-tb-031-exercise-overview.pdf)** — Boletín técnico sobre prescripción de ejercicio aeróbico y de resistencia en microgravedad.
- **[NASA Space Radiation Analysis Group (SRAG) — Radiation FAQ](https://srag.jsc.nasa.gov/SpaceRadiation/FAQ/FAQ.cfm)** — Tasas de dosis operacionales en la ISS, Anomalía del Atlántico Sur (SAA) y eventos de partículas solares (SEP).
- **[NASA TechPort](https://techport.nasa.gov/)** — Portafolio tecnológico de la NASA (incluye *Project 97109: Head-Mounted Visual Assessment System* para monitoreo de SANS).
- **[NASA Open Science Data Repository (OSDR / GeneLab)](https://osdr.nasa.gov/)** — Repositorio de datos biomédicos espaciales y referencia de telemetría de misiones comerciales como *Inspiration4*.

---

## 2. 🩺 Literatura Científica y Fisiología Espacial (4 Dimensiones Pasivas, Radiación, SAS/SMS y SANS)

### Dimensión 1: Cardiorrespiratoria, Metabólica y Termorregulación
- **[Canadian Space Agency (CSA) — Bio-Monitor: Keeping an eye on astronauts' vital signs](https://www.asc-csa.gc.ca/eng/sciences/bio-monitor.asp)** — Sistema de prenda inteligente de monitoreo continuo en la ISS (ECG, FC, FR, SpO₂, temperatura cutánea y acelerometría).
- **[Mendes Zambetta et al. (2024) — Effects of microgravity on cardiac autonomic control: A systematic review](https://doi.org/10.3389/fphys.2024.1438089)** (*Frontiers in Physiology*) — Fundamento de los cambios en variabilidad de la frecuencia cardíaca (HRV: RMSSD y SDNN) en microgravedad.
- **[Stahn et al. (2017) — Increased core body temperature in astronauts during long-duration space missions](https://doi.org/10.1038/s41598-017-15560-w)** (*Scientific Reports*) — Estudio sobre la fiebre espacial (*Space Fever*, elevación basal de ~1 °C) medida con sensores de doble flujo térmico (*Draeger Double Sensor*).
- **[Fine et al. (2021) — Sources of inaccuracy in photoplethysmography for continuous cardiovascular monitoring](https://doi.org/10.3390/bios11040126)** (*Biosensors*) — Limitaciones de PPG frente a artefactos de movimiento y redistribución cefálica de fluidos.
- **[Berry et al. (2012) — Rules for scoring respiratory events in sleep: Update of the AASM Manual](https://doi.org/10.5664/jcsm.2172)** (*Journal of Clinical Sleep Medicine*) — Criterios clínicos de hipopnea/apnea y desaturación de SpO₂.
- **[American Heart Association (AHA) — Target Heart Rates Chart](https://www.heart.org/en/healthy-living/fitness/fitness-basics/target-heart-rates)** — Zonas de frecuencia cardíaca máxima y submáxima durante contramedidas de ejercicio.
- **[National Heart, Lung, and Blood Institute (NHLBI, 2023) — Pulse Oximetry](https://www.nhlbi.nih.gov/health/pulse-oximetry)** — Rangos clínicos de saturación de oxígeno (SpO₂).

### Dimensión 2: Neurológica, Sensoriomotora (SAS/SMS), Neuro-Ocular (SANS) y Cognitiva (PVT)
- **[Lee et al. (2020) — Spaceflight associated neuro-ocular syndrome (SANS) and the neuro-ophthalmologic effects of microgravity](https://doi.org/10.1038/s41526-020-0097-9)** (*NPJ Microgravity*) — Fisiopatología, edema de disco óptico, pliegues coroideos, cambio hipermetrópico (*shift* dióptrico) y rejilla de Amsler.
- **[Macias et al. (2020) — Association of long-duration spaceflight with anterior and posterior ocular structure changes in astronauts](https://doi.org/10.1001/jamaophthalmol.2020.0673)** (*JAMA Ophthalmology*) — Cuantificación estructural de SANS en vuelos de larga duración.
- **[Basner & Dinges (2011) — Maximizing sensitivity of the psychomotor vigilance test (PVT) to sleep loss](https://doi.org/10.1093/sleep/34.5.581)** (*Sleep*) — Métricas de tiempo de reacción (RT) y lapsos (>355 ms / >500 ms) para fatiga cognitiva en tripulaciones.
- **[Basner, Mollicone & Dinges (2011) — Validity and sensitivity of a brief psychomotor vigilance test (PVT-B) to acute total and chronic partial sleep deprivation](https://doi.org/10.1016/j.actaastro.2011.07.015)** (*Acta Astronautica*) — Validación del test corto de 3 minutos (*PVT-B / Reaction Self Test* de la ISS).
- **Graybiel, A., Wood, C. D., Miller, E. F., & Cramer, D. B. (1968).** *Diagnostic criteria for grading the severity of acute motion sickness.* Aerospace Medicine, 39(5), 453–455. — Base clínica de la Escala Diagnóstica de Graybiel para el Síndrome de Adaptación Espacial (SAS) / *Space Motion Sickness* (SMS).

### Dimensión 3: Musculoesquelética, Ejercicio y Contramedidas
- **[Petersen et al. (2016) — Exercise in space: The European Space Agency approach to in-flight exercise countermeasures for long-duration missions on ISS](https://doi.org/10.1186/s13728-016-0050-4)** (*Extreme Physiology & Medicine*) — Protocolos operativos de ARED (resistencia), T2 (cinta rodante) y CEVIS (cicloergómetro) para mitigar atrofia muscular y osteopenia.

### Dimensión 4: Ritmo Circadiano, Sueño y Actigrafía
- **[Barger et al. (2014) — Prevalence of sleep deficiency and use of hypnotic drugs in astronauts before, during, and after spaceflight](https://doi.org/10.1016/S1474-4422(14)70122-X)** (*The Lancet Neurology*) — Estudio de referencia sobre deficiencia crónica de sueño (~6.0 h/noche) y desalineación circadiana en misiones espaciales.
- **[Hirshkowitz et al. (2015) — National Sleep Foundation's sleep time duration recommendations](https://doi.org/10.1016/j.sleh.2014.12.010)** (*Sleep Health*) — Recomendaciones de duración de sueño por rango etario.
- **[Sadeh (2011) — The role and validity of actigraphy in sleep medicine: An update](https://doi.org/10.1016/j.smrv.2010.10.001)** (*Sleep Medicine Reviews*) — Fundamentos y validez de la actigrafía para latencia, despertares y eficiencia del sueño.
- **[Smith et al. (2018) — Use of actigraphy for the evaluation of sleep disorders and circadian rhythm sleep-wake disorders](https://doi.org/10.5664/jcsm.7230)** (*Journal of Clinical Sleep Medicine*) — Guía clínica de la AASM para evaluación actigráfica.
- **[Watson et al. (2015) — Recommended amount of sleep for a healthy adult](https://doi.org/10.5665/sleep.4716)** (*Sleep*) — Consenso conjunto AASM/SRS sobre horas recomendadas de descanso.

---

## 2.1 📊 Fuentes de los datos de `DB/` (muestras y biomarcadores)

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

---

## 3. 🛰️ APIs Públicas de Clima Espacial (Solo Documentación Oficial, Sin Credenciales)

- **[NASA Open APIs Portal](https://api.nasa.gov/)** — Portal público de APIs abiertas de la NASA.
- **[NASA CCMC — DONKI (Space Weather Database Of Notifications, Knowledge, Information)](https://ccmc.gsfc.nasa.gov/tools/DONKI/)** — Documentación oficial de los endpoints públicos de clima espacial (`FLR` para llamaradas solares y `SEP` para eventos de partículas energéticas solares), utilizados con fallback 100% offline en el módulo de Radiación.

---

## 4. 💻 Stack Tecnológico, Librerías Open-Source y Modelos Locales (Offline-First)

### Frontend & Arquitectura Mobile/Desktop
- **[Flutter Documentation](https://docs.flutter.dev/)** — Framework UI multiplataforma (Android, iOS, Web, Desktop).
- **[Riverpod (`flutter_riverpod`)](https://riverpod.dev/)** — Gestión de estado reactiva y desacoplada.
- **[Hive (`hive` / `hive_flutter`)](https://docs.hivedb.dev/)** — Base de datos NoSQL local ultrarrápida para persistencia offline de telemetría y triage.
- **[fl_chart](https://pub.dev/packages/fl_chart)** — Motor de visualización de series temporales biomédicas y curvas dosimétricas.
- **[camera](https://pub.dev/packages/camera)** y **[sensors_plus](https://pub.dev/packages/sensors_plus)** — Captura de cámara y sensores inerciales (acelerómetro/giroscopio) para el HUD de visión computacional (rPPG, pupilometría, escaneo de tiras reactivas y estabilidad vestibular).

### Asistente Clínico APOLO (Voz e IA Local / Híbrida)
- **[Faster-Whisper (SYSTRAN)](https://github.com/SYSTRAN/faster-whisper)** — Transcripción de voz a texto (STT) optimizada con CTranslate2 para operación local.
- **[Kokoro-82M (hexgrad)](https://huggingface.co/hexgrad/Kokoro-82M)** — Modelo TTS neural ligero (82M parámetros, licencia Apache-2.0) para síntesis de voz natural offline.
- **[Piper TTS (rhasspy)](https://github.com/rhasspy/piper)** — Sistema rápido y local de síntesis de voz neural para respuestas de baja latencia.
- **[FastAPI](https://fastapi.tiangolo.com/)** — Framework para el servidor puente local de procesamiento de voz y orquestación de herramientas médicas.

---

## 5. 📂 Índices y Documentación Interna Relacionada en el Repositorio

- [`DB/references.md`](../DB/references.md) — Bibliografía detallada en formato APA 7.ª edición por cada variable fisiológica.
- [`DB/scientific_criteria.json`](../DB/scientific_criteria.json) — Rangos operativos nominales, de advertencia y críticos parametrizados para la aplicación.
- [`sources/medical/radiation_dosimetry.md`](./medical/radiation_dosimetry.md) — Marco clínico y operacional de dosimetría de radiación espacial.
- [`sources/nasa/challenge_brief.md`](./nasa/challenge_brief.md) — Resumen oficial del reto de NASA Space Apps Challenge.
- [`sources/notes/final_product_concept_and_roadmap.md`](./notes/final_product_concept_and_roadmap.md) — Concepto de producto final, análisis de brechas y hoja de ruta del proyecto.
