# Referencia de dosimetría para el módulo de radiación

Consulta realizada el 14 de noviembre de 2026. Priorizar el estándar oficial vigente cuando se revisen umbrales antes de una presentación o de cualquier uso fuera de la demo.

## Fuentes primarias

1. NASA, [NASA-STD-3001 Volume 1, Revision C](https://www.nasa.gov/wp-content/uploads/2023/11/nasa-std-3001-vol-1-rev-c-with-signature.pdf), secciones 4.8.2–4.8.5 y tablas 4.8-1 y 4.8-2. La tabla 4.8-1 (página impresa 40) da límites para lente, piel, órganos hematopoyéticos, sistema circulatorio y SNC.
2. NASA OCHMO, [OCHMO-TB-020, Design for Ionizing Radiation Protection, Revision G (2025)](https://www.nasa.gov/wp-content/uploads/2023/12/ochmo-tb-020-radiation-protection.pdf), resumen de requisitos y explicaciones de dosis efectiva.
3. NASA Space Radiation Analysis Group, [Radiation FAQ](https://srag.jsc.nasa.gov/SpaceRadiation/FAQ/FAQ.cfm), distinción entre dosis absorbida (Gy) y dosis equivalente (Sv) y factores de calidad.

## Valores de referencia

| Referencia | Valor | Uso previsto |
|---|---:|---|
| Dosis efectiva de carrera espacial [V1 4030] | <600 mSv | Presupuesto de carrera de cada astronauta, incluyendo dosis previa y dosis de misión. |
| Evento solar de diseño [V1 4031] | <250 mSv de dosis efectiva | Referencia de diseño/protección para un SPE; no clasifica por sí sola un SPE real en vivo. |
| GCR, sistema en espacio libre [V1 4033] | <1.3 mSv/día | Requisito de protección del diseño para misiones de más de 60 días; no es un umbral clínico individual. |
| GCR, sistema en superficie planetaria [V1 4033] | <0.9 mSv/día | Requisito de protección del diseño para misiones de más de 60 días. |
| Tecnologías nucleares [V1 4032] | <20 mSv por año de misión | Fuera del alcance de la muestra del prototipo. |

Límites por órgano de la tabla 4.8-1:

| Órgano/sistema | 30 días | 1 año | Carrera |
|---|---:|---:|---:|
| Cristalino | 1000 mGy-Eq | 2000 mGy-Eq | 4000 mGy-Eq |
| Piel | 1500 mGy-Eq | 3000 mGy-Eq | 6000 mGy-Eq |
| Órganos hematopoyéticos | 250 mGy-Eq | 500 mGy-Eq | No aplica |
| Sistema circulatorio | 250 mGy-Eq | 500 mGy-Eq | 1000 mGy-Eq |
| Sistema nervioso central (hipocampo) | 500 mGy | 1000 mGy | 1500 mGy |
| Sistema nervioso central, iones Z≥10 | No aplica | 100 mGy | 250 mGy |

La tabla distingue mGy-Eq y mGy; la aplicación debe comparar cada órgano con su límite en la unidad correspondiente. La dosis efectiva en mSv no se debe convertir directamente en dosis de órgano sin espectro, geometría y ponderaciones apropiadas.

## Decisiones para la simulación

- Se crea un escenario reproducible, ficticio y marcado como `synthetic_demo`.
- El SPE ocurre el día 95; el estado del clima espacial se simula como alerta ese día.
- La dosis de carrera se calcula sumando la dosis previa del perfil más las dosis efectivas diarias de la misión.
- Las dosis por órgano son entradas sintéticas de demostración y no se infieren de la dosis efectiva.
- El documento de diseño del equipo menciona 1.8 mSv/día para tránsito. La muestra usa un valor central ilustrativo de 1.65 mSv/día y no lo presenta como límite NASA. NASA-STD-3001 Rev. C separa los requisitos de protección GCR de 1.3 mSv/día en espacio libre y 0.9 mSv/día en superficie planetaria.
- Todos los semáforos del prototipo son ilustrativos; no constituyen evaluación clínica ni recomendación médica.
