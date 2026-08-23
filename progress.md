# Progress log

## 2026-08-23
- Propuesta de rediseño de corrMatrix discutida y aprobada por el usuario.
- Confirmado: modo "vs. resto" usa 2 cajas separadas; nombre del módulo
  `corrInspect` (confirmado vía AskUserQuestion).
- Creados task_plan.md / findings.md / progress.md.
- Escrito el paquete `corrInspect/` completo: DESCRIPTION, NAMESPACE,
  jamovi/{0000.yaml, corrinspect.a.yaml, corrinspect.r.yaml,
  corrinspect.u.yaml}, R/{corrCompute.R, corrinspect.b.R},
  tests/testthat/test-corrCompute.R.
- Bash/shell del sandbox se degradó durante la sesión ("shell level 1000",
  fork exhaustion en /Users/h501uvma/.local/bin/claude) — trabajado
  alrededor evitando comandos de fondo y usando timeouts cortos.
- `jmvtools::prepare()` falla en el sandbox ("a newer version of the
  jamovi-compiler (or jmvtools) is required"), reproducido también en
  conttables2xK → problema de entorno (node v26.7.0 muy nuevo para
  jamovi-compiler 0.3.5), no del código nuevo. Detalle en README.md.
- Verificación alternativa realizada: tests unitarios de la capa
  estadística pura (corrCompute.R) contra cor.test — todos pasan.
  Introspección directa de la API real de jmvcore (R6 class methods) con
  R 4.5-arm64 confirmó que todos los métodos usados en corrinspect.b.R
  existen con la firma esperada (addRow/setRow/setTitle/setSize/
  setVisible/addItem/$key).
- git init dentro de jamovi-corr/ (repo independiente, como los módulos
  hermanos) + primer commit.
- Pendiente: compilar en la máquina del usuario y probar en jamovi real.

## 2026-08-23 (cont.)
- Adaptado `tools/install.sh` de jamovi-jmvplus para corrInspect (build +
  install en desktop y docker). Smoke tests propios en docker (allVsAll y
  refVsRest contra cor() base R), reemplazando los de jmvplus (CV,
  intervalo de predicción de scat, que no aplican aquí).
  No adaptados (no pedidos): prepare-jmo.sh, release.sh.
  Nota dejada en el script: --skip-deps asume que gridExtra ya está
  disponible en el contenedor; si el smoke test falla por eso, instalarlo
  a mano en el contenedor primero.

## 2026-08-23 (ronda 2 — feedback tras compilar en la máquina del usuario)
- Confirmado: el build SÍ funciona en la máquina del usuario (desktop +
  docker vía tools/install.sh). El único fallo real fue NAMESPACE sin
  `export(corrInspect)` → arreglado.
- Bug encontrado por el usuario, arreglado: heatmap se activaba solo por
  tener >2 variables en vez de ser una opción → nueva opción `heatmap`
  separada de `plots`.
- Bug reportado "density no hace nada": no reproducido en un script
  standalone (gridExtra::grid.arrange con densidades marginales dibuja
  bien fuera de jamovi); sospecha de que era consecuencia del bug del
  heatmap (con >2 variables el heatmap tapaba el scatter, que es el único
  que respeta plotDens) — pendiente confirmación del usuario.
- IC95%: 2 → 3 decimales (ciText). Implementado IC95% para Spearman y
  Kendall (no lo tenían) vía Fisher z + corrección de Fieller, Hartley &
  Pearson (1957), Var(z)=0.437/(n-4) — investigado con WebSearch (Cross
  Validated bloqueó WebFetch con 403 en las URLs que probé).
- Rediseño mayor de UI: eliminado el option `mode` y el box `compareVars`;
  ahora solo `vars` + `refVar` (opcional) — si `refVar` tiene valor, el
  análisis pasa a "una vs. el resto" automáticamente, comparando `refVar`
  contra `setdiff(vars, refVar)`.
- `R/corrinspect.h.R` borrado del repo (quedó desincronizado del nuevo
  a.yaml y no se pudo regenerar en este sandbox); se regenera solo en el
  próximo build del usuario.
- Pendiente: que el usuario reconstruya y confirme, en particular si
  `enable: (refVar)` en el .u.yaml compila (sintaxis no verificada para
  un option tipo Variable).

## 2026-08-23 (ronda 3 — diseño aprobado + bugs de plots/heatmap + i18n)
- Diseño de la ronda 2 confirmado por el usuario ("más simple y igual de
  funcional").
- Causa real de "Scatterplots no muestra ningún plot": nunca implementé
  contenido para el caso allVsAll + >2 variables + plots (solo existía el
  heatmap ahí). Nueva `.drawScatterMatrix()` (grid.arrange de mini-scatter
  por par, triángulo inferior + diagonal con nombre de variable).
  Verificado standalone con mtcars antes de integrar.
- Separados `plotScatter` y `plotHeatmap` en dos Image independientes
  (antes compartían un único `plotAllVsAll`, por lo que activar ambas
  casillas a la vez era imposible aunque fueran opciones "independientes"
  — bug de arquitectura, no solo de UI).
- Heatmap: bug real encontrado — `.heatmap()` usaba `stats::cor()` a pelo
  (siempre Pearson), ignorando qué coeficiente estuviera seleccionado.
  Arreglado con nueva opción `heatmapMethod` (List) usando `corrFit()`.
  Nueva opción `heatmapDetails` (Bool) añade IC95%/p/N/flag a cada celda,
  reutilizando los checkboxes ya existentes de la tabla (ci/sig/n/flag)
  en vez de opciones nuevas por estadístico, como pidió el usuario.
- i18n: creados `jamovi/i18n/es.po` y `jamovi/i18n/ca.po` (mismo formato
  y ubicación que conttables2xK, revisado como referencia). ~35 msgid
  traducidos: título/subtítulo/descripción del módulo, todas las opciones
  visibles, labels de agrupación, tabla/columnas, títulos de plots. Sin
  traducir (alcance limitado, comunicado al usuario): tooltips largos y
  cadenas generadas dinámicamente en R (no verifiqué el mecanismo de
  i18n del lado R backend).
- Limpiados `Rplots.pdf` sueltos (efecto secundario de mis pruebas
  standalone con gridExtra) y añadidos a .gitignore en ambos niveles.
- `R/corrinspect.h.R` reapareció sin trackear (el usuario reconstruyó
  entre rondas) pero quedó obsoleto de nuevo tras las nuevas opciones —
  dejado fuera de git otra vez.
- Pendiente: reconstruir y confirmar en jamovi real, especialmente
  `enable: (refVar)` (arrastrado sin verificar desde la ronda 2) y que
  las traducciones se apliquen correctamente al cambiar idioma.
