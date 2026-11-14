# Datos reales de Inspiration4 (NASA OSDR)

Análisis clínicos **reales** de los 4 tripulantes de la misión Inspiration4
(SpaceX, septiembre de 2021, 3 días en órbita), publicados por la NASA en el
Open Science Data Repository (OSDR). Los tripulantes son anónimos (C001–C004).

Visitas: L-92, L-44 y L-3 (días antes del lanzamiento); R+1, R+45, R+82 y
R+194 (días después del regreso).

| Archivo | Estudio | Qué tiene | Se usa en el código |
|---|---|---|---|
| `LSDS-7_Complete_Blood_Count_CBC.upload_SUBMITTED.csv` | [OSD-569](https://osdr.nasa.gov/bio/repo/data/studies/OSD-569) | Hemograma: linfocitos, neutrófilos, leucocitos… | **Sí**: línea base de sangre, variación entre visitas y cambio al regresar |
| `LSDS-7_..._CBC_TRANSFORMED.csv` | OSD-569 | Lo mismo, en formato ancho | No |
| `LSDS-8_Comprehensive_Metabolic_Panel_CMP*.csv` | [OSD-575](https://osdr.nasa.gov/bio/repo/data/studies/OSD-575) | Química: creatinina sérica, glucosa, electrolitos… | Todavía no |
| `LSDS-8_Multiplex_serum.immune.EvePanel_SUBMITTED.csv` y `_TRANSFORMED` | OSD-575 | Citoquinas en suero (pg/mL), incluida IL-6 | Todavía no |
| `LSDS-8_Multiplex_serum.immune.AlamarPanel_TRANSFORMED.csv` | OSD-575 | Proteínas inmunes en suero (unidades relativas NPQ) | No |
| `LSDS-64_Multiplex_urine.immune.AlamarPanel_TRANSFORMED.csv` | [OSD-656](https://osdr.nasa.gov/bio/repo/data/studies/OSD-656) | Proteínas inmunes en **orina** (NPQ) | No |
| `files_OSD-*.json` | — | Lista de archivos de cada estudio, con sus enlaces de descarga | — |

## Lo que muestran los datos (y usamos)

- **Linfocitos antes del vuelo:** 2,1–2,6 ×10⁹/L de media por persona.
- **Variación normal entre visitas de una misma persona:** ~25 % en linfocitos y
  ~17 % en neutrófilos. Por eso un cambio de ese tamaño en un solo análisis
  **no** indica daño por radiación.
- **Al día siguiente del regreso (R+1):** linfocitos −18 % de media (3 de 4
  bajan) y neutrófilos −14 %. Inspiration4 recibió solo unos pocos mSv, así que
  este cambio se debe al vuelo (estrés, líquidos, regreso a la gravedad) y no a
  la radiación. Es un factor de confusión que el monitor debe tener en cuenta.
- **IL-6 en R+1** sube en los 4 tripulantes (~+60–90 %); queda como posible
  marcador a futuro.

## Corrección aplicada

En C003, visita L-92, el archivo trae `ABSOLUTE NEUTROPHILS = 10.1` y
`ABSOLUTE LYMPHOCYTES = 6826` células/µL. Con los leucocitos del mismo análisis
(9,6 mil/µL) y los porcentajes (71,1 % neutrófilos, 20,8 % linfocitos), los
valores correctos son ≈ 6826 neutrófilos y ≈ 1997 linfocitos. En el código se usan
los corregidos (`lib/features/02_radiation/data/inspiration4_reference.dart`) y
una prueba lo comprueba contra este archivo.

## Otras fuentes usadas por el simulador (orina)

- 8-OHdG urinario en adultos sanos: 3,9 ng/mg de creatinina (rango
  intercuartílico 3–5,5), métodos químicos. Metaanálisis de Graille M. et al.,
  2020 (8-OHdG urinario en población sana).
- Astronautas de Mir: el 8-OHdG no cambia en vuelo y los isoprostanos bajan
  ~20 %. Stein T.P. & Leskiw M.J., 2000.
  https://ntrs.nasa.gov/citations/20040141642
- ISS (n = 13): el 8-OHdG urinario es 22 % mayor después del vuelo. Smith S.M. &
  Zwart S.R., NASA 2006.
  https://ntrs.nasa.gov/api/citations/20060049121/downloads/20060049121.pdf

Son **aproximados** (no hay datos públicos de astronautas): los isoprostanos,
el MDA, la creatinina urinaria, la PCR y el efecto de la dosis (≈ −50 % de
linfocitos por Gy).
