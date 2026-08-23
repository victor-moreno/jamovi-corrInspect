# Findings

## jmv::corrMatrix (referencia, /Applications/jamovi.app .../modules/jmv/ui/corrmatrix.js)
Opciones: vars, pearson (default TRUE), spearman, kendall, sig (default TRUE),
flag, n, ci, ciWidth (default 95), plots (matriz), plotDens, plotStats,
hypothesis (corr/pos/neg).
Tabla: matriz n×n, cada celda con sub-filas apiladas (r, df, p, IC-lower,
IC-upper) -> mucho ancho y muchas rayas. Se reemplaza por tabla tidy.

## jamovi-jmvplus/jmvplus (scat.b.R) — patrón para anotar scatterplots
Envuelve el renderer de scatr (`.scatterPlot`) sin reemplazarlo:
- `unlockBinding`/`lockBinding` sobre `.scatterPlot` en el enclosing env del
  padre, para inyectar capas extra sin duplicar el plot base.
- Banda de predicción: `geom_ribbon` desde `predict(lm, interval="prediction")`
  sobre una rejilla de 100 x, con `alpha=0.30`.
- Anotación de texto: `annotate("text", x=Inf, y=Inf, hjust=1.05, vjust=1.5)`
  con `r = %.3f\ny = %g + %g*x` — esquina superior derecha.
Reutilizable como referencia de estilo para los scatter del módulo `corr`,
pero `corr` construye su propio plot (no envuelve otro análisis) porque
scat depende de `scatr::scat` como addon, y `corr` es standalone.

## Convenciones de paquete (jamovi-conttables-2xK/conttables2xK/DESCRIPTION)
Authors@R: Ravi Selker, Jonathon Love, Damian Dropmann (aut, cph, originales
de jmv) + Victor Moreno (aut, cre, cph, maintainer) + contribuidores jmv.
Depends: R (>= 3.2). Imports: jmvcore (>= 2.4.2), R6, ggplot2 (>= 2.2.1) +
lo específico del análisis. License: GPL (>= 2). Language: en-GB.
BugReports apunta a jmv upstream (no aplica igual para `corr`: no es PR a
jmv, es módulo independiente — ajustar BugReports/Description en consecuencia).
