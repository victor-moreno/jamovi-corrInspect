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

## 2026-08-23 (ronda 4 — layout pares/matrix, toggles del scatter, heatmap en modo referencia)
- Unificado el Array `plotRefVsRest` con el nuevo caso "pares" de
  allVsAll en un solo `plotPairs`, renombrado renderFun a `.plotPairs`;
  decide modo referencia vs. pares por si la key del item contiene "|".
  Nueva opción `plotsFormat` (matrix/pairs, default matrix) para elegir
  el layout cuando hay >2 variables sin referencia.
- 3 opciones nuevas para el scatter anotado: `plotR`, `plotLine`,
  `plotEquation` (todas Bool, default TRUE). Reutilizado `sig` (ya
  existente) para el toggle de p en el scatter, en vez de duplicar.
  Aplican a cualquier scatter anotado (2 vars, pares, o referencia).
- Alineación del texto de anotación: `hjust=-0.05` → `hjust=0`
  (izquierda real). Verificado visualmente (PNG standalone) antes de
  integrar.
- Opción `plotDens` eliminada por completo (a.yaml/u.yaml/r.yaml/b.R) a
  petición directa del usuario — no investigué por qué "no funcionaba",
  solo la quité.
- `.heatmap()` ahora soporta modo referencia: columna única (var1=refVar,
  n filas = restVars) en vez de matriz n×n. `.plotHeatmap` y
  `.updateVisibility` ya no excluyen refMode.
- Heatmap: `coord_fixed()` (celdas cuadradas garantizadas pase lo que
  pase con el ancho de la leyenda) + `theme(legend.position='bottom')` +
  imagen +90px de alto. Verificado visualmente (n×n y columna única)
  con PNG standalone antes de integrar.
- `ciText()` acepta ahora `decimals` (default 3); heatmap details usa
  `decimals=2` para que el IC coincida con los 2 decimales que ya usa
  el heatmap para r (tabla y scatter siguen en 3, sin cambios ahí).
- i18n: quitadas entradas de "Densities for variables" y "Plot" (Label
  genérico ya no usado); añadidas "Layout"/"Matrix"/"Pairs"/"Regression
  line"/"Line equation" en es.po y ca.po.
- Pendiente: todo lo de rondas 2-3 sin confirmar sigue sin confirmar
  (`enable: (refVar)`, traducciones), más lo nuevo de esta ronda —
  especialmente el layout "Pairs" (la pieza arquitectónicamente más
  compleja de este round) y el heatmap en modo referencia, ninguno de
  los dos probado en jamovi real todavía.

## 2026-08-23 (ronda 5 — confirmaciones, i18n dinámico, estética scatter/heatmap)
- Confirmado por el usuario: `enable: (refVar)` funciona, y las
  traducciones funcionan. Ambos pendientes cerrados.
- Bug nuevo sin diagnosticar: añadir un factor a "Reference variable" da
  error. No tengo el texto exacto — pedido al usuario, no adiviné un fix.
- Hallazgo importante investigando el pedido de traducir "Pearson's r":
  `jmvcore::Analysis` tiene un método público `self$translate(text)` que
  lee el MISMO `inst/i18n/<lang>.json` ya generado desde
  `jamovi/i18n/*.po` (confirmado leyendo el código fuente real de
  jmvcore instalado: `Options$translate`/`createTranslator`). Un solo
  catálogo sirve para yaml Y para strings generados en R. Aplicado a
  `methodLabel()` (columna stat de las tablas, leyenda del heatmap) y al
  título dinámico de tableRefVsRest. Añadidas las entradas que faltaban
  a es.po/ca.po.
- Alineación de anotaciones: hjust ajustado (0→0.02 en scatter anotado,
  -0.1→0.05 en matriz) para que no queden pegadas/fuera del eje.
- Recorte del eje Y: la banda de predicción puede extenderse muy por
  debajo del rango real de los datos (verificado con ejemplo standalone:
  datos en [0,30], banda hasta -13) arrastrando el eje con ella.
  Cambiado a `coord_cartesian(ylim=...)` calculado sobre los DATOS, con
  margen inferior 5% y superior 15% (para la anotación) — resuelve a la
  vez "eje 0 muy alto con espacio en blanco" y "aumenta la escala para
  la leyenda". Verificado antes/después con PNG standalone.
- Color fijo en scatters (ya no derivado del tema de jamovi): puntos
  azul claro `#5DADE2`, línea y ejes negros. Aplicado a scatter anotado
  y matriz de scatters.
- Heatmap: fuente de la leyenda reducida (8/7pt) y barra de color
  ensanchada (`guide_colorbar` 5cm de ancho). Verificado con PNG
  standalone.
- Pendiente: texto exacto del error de refVar+factor (bloqueante para
  ese punto); confirmar en jamovi real el layout "Pairs", el heatmap en
  modo referencia, el recorte de eje Y con datos reales, y la estética
  del heatmap a tamaños reales de panel.

## 2026-08-23 (ronda 6 — fix del bug refVar+factor)
- Usuario dio el error exacto: `var(x) on a factor x is defunct`, en
  `corrFit() → stats::sd(y)`. Confirmado probando `jmvcore::toNumeric()`
  directamente contra un factor nominal de texto: lo deja sin convertir
  (comportamiento correcto de toNumeric, no un bug suyo). El bug real:
  `vars`/`refVar` permitían `factor` en a.yaml (copiado de
  jmv::corrMatrix), dejando pasar un factor nominal hasta `sd()`.
- Fix: `permitted: [numeric, factor]` → `permitted: [numeric]` en ambas
  opciones; `suggested` ajustado a `[continuous]`. Jamovi ahora bloquea
  el factor en el propio panel — sin tocar código R, la vía de entrada
  queda cerrada en la UI.
- Pendiente: reconstruir y confirmar que el factor ya no se puede
  arrastrar; el resto de puntos abiertos de rondas 4-5 sigue igual.
