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

## 💻 Herramientas y APIs
- *(Añade aquí enlaces a APIs de telemetría o librerías)*
