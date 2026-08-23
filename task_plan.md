# Plan: módulo jamovi "corr" (clon limpio de jmv::corrMatrix)

## Objetivo
Clonar `jmv::corrMatrix` con presentación mejorada:
- 2 variables: tabla tidy mínima (1 fila), sin andamiaje de matriz.
- >2 variables, modo "una vs. el resto": 2 cajas (variable de referencia +
  variables a comparar), tabla tidy (n-1 filas), galería de scatterplots
  anotados (estilo `jmvplus::scat`: r, IC95%, ecuación, banda de predicción).
- >2 variables, modo "todas contra todas": tabla tidy (n·(n-1)/2 filas) +
  plot matriz con celdas coloreadas por magnitud/signo de r (heatmap) en vez
  de texto plano.
- IC95% se funde en una sola celda/sub-fila "[lower, upper]", no en columnas
  separadas.

Contexto completo de la propuesta ya discutida y aprobada por el usuario está
en la conversación; este archivo es memoria de trabajo para la implementación.

## Decisiones ya tomadas (no reabrir)
- Nombre de paquete/módulo: `corrInspect` (confirmado por el usuario
  2026-08-23, vía AskUserQuestion). Ruta del paquete R:
  `jamovi-corr/corrInspect/`.
- Arquitectura de opciones/resultados (decidida durante el diseño, no
  reabrir sin razón):
  - Un único option `mode` (List: allVsAll default / refVsRest) controla
    todo. Con `vars` de longitud 2 en modo allVsAll, la tabla tidy ya
    produce 1 sola fila de forma natural — NO hace falta un modo "2
    variables" aparte, allVsAll con n=2 ES ese caso.
  - Cajas de variables: `vars` (Variables, para allVsAll) + `refVar`
    (Variable, maxItemCount 1) + `compareVars` (Variables), ambas dentro
    del mismo VariableSupplier, siempre visibles, atenuadas con
    `enable: "(mode:allVsAll)"` / `enable: "(mode:refVsRest)"`. Se evaluó
    `ModeSelector` (existe en el schema del compilador,
    jamovi-compiler/schemas/uictrlschemas.yaml) pero no se usa en ningún
    módulo de jmv (grep sin resultados) — demasiado riesgo sin ejemplo de
    referencia, se descarta para v1.
  - Resultados: `tableAllVsAll` / `tableRefVsRest` (Table, cada uno con
    `visible: (mode:...)`, confirmado que `visible:` en .r.yaml acepta
    binding de opción — yaml-and-compiler.md línea ~112).
  - Plot allVsAll: UN solo Image (`plotAllVsAll`) cuyo renderFun decide
    internamente: si `length(vars)==2` dibuja un scatter anotado (estilo
    jmvplus::scat: r, IC95%, ecuación, banda de predicción); si
    `length(vars)>2` dibuja un heatmap (geom_tile coloreado por r).
  - Plot refVsRest: `Array` de Image (`plotRefVsRest`), un item por
    variable en `compareVars`, cada uno con la misma anotación scatter.
  - Se pospone la versión "matriz de scatterplots con densidad diagonal"
    (estilo GGally) para el heatmap allVsAll con n>2 — v1 es solo
    heatmap de color, sin diagonal de densidades. Mencionar como posible
    mejora futura al usuario.
- Modo "vs. resto": 2 cajas separadas (variable de referencia + variables a
  comparar), NO depende del orden en una sola lista. Confirmado por el
  usuario 2026-08-23.
- Reemplaza la tabla-matriz clásica de jmv por completo (no se mantiene como
  alternativa) — el aspecto "matriz" sobrevive solo en el plot con color.
- Paridad de opciones con jmv: Pearson/Spearman/Kendall, sig, flag, n, IC.
- DESCRIPTION sigue el patrón de `jamovi-conttables-2xK`: Authors@R con los
  autores originales de jmv (Selker, Love, Dropmann) + Victor Moreno como
  maintainer/cre, ya que es un clon derivado de jmv::corrMatrix.

## Fases

### Fase 0 — Andamiaje del paquete (pending)
- DESCRIPTION, NAMESPACE, .gitignore, .Rbuildignore
- jamovi/0000.yaml, jamovi/00refs.yaml
- git init + primer commit

### Fase 1 — Modo 2 variables (pending)
- corr.a.yaml (options): vars (mín 2), pearson/spearman/kendall, sig, ci,
  ciWidth, flag, n
- corr.r.yaml: tabla tidy + Image(s) para scatter
- corr.b.R: detectar nvars==2 -> 1 fila, 1 scatter anotado (estilo scat.b.R)
- Instalar y probar en jamovi real con datos de ejemplo

### Fase 2 — Modo "una vs. el resto" (pending)
- añadir option `mode` (list: allVsAll/refVsRest), boxes `refVar` (Variable,
  maxItemCount:1) y `compareVars` (Variables)
- galería de scatterplots (uno por comparación)
- opción eje: refVar en X o en Y

### Fase 3 — Modo "todas contra todas" (pending)
- tabla tidy n(n-1)/2 filas
- plot matriz con heatmap de color por r

### Fase 4 — Pulido y tests (pending)
- tests/testthat (oracle: cor.test base R)
- build final, jmvtools::install(), prueba manual en la app

## Errores encontrados
- 2026-08-23: comandos `find`/background bash mostraron warnings "shell level
  (1000) too high" / fork failures en un proceso de fondo — parece artefacto
  del entorno sandbox, no relacionado con los comandos en sí. Mitigación:
  evitar comandos de fondo innecesarios, usar comandos puntuales con timeout
  explícito, no lanzar find recursivo sobre symlinks grandes (jamovi-src).

## Estado (2026-08-23, fin de sesión)
Fases 0-3 escritas en un solo pase (DESCRIPTION/NAMESPACE, .a/.r/.u.yaml,
corrCompute.R, corrinspect.b.R con las 2 tablas tidy, el scatter anotado,
el heatmap y la galería refVsRest). Verificado sin poder compilar el módulo:
- `R/corrCompute.R` (toda la capa estadística pura) pasa
  `tests/testthat/test-corrCompute.R` contra `stats::cor.test` como oráculo
  (pearson/spearman/kendall, missing data, casos degenerados).
- Las llamadas a la API de jmvcore usadas en `corrinspect.b.R`
  (`Table$addRow/setRow/setTitle`, `Image$setSize/setVisible`,
  `Array$addItem(key=)`, `ResultsElement$key`) se confirmaron por
  introspección directa de las clases R6 instaladas
  (`jmvcore:::Table$public_methods`, etc.) con R 4.5-arm64 — no por
  ejecutar el análisis real.
- NO se pudo ejecutar `jmvtools::prepare()`/`install()`: falla con "a newer
  version of the jamovi-compiler (or jmvtools) is required", reproducido
  también en `conttables2xK` (módulo hermano que sí compila normalmente en
  la máquina del usuario) → problema del toolchain de este sandbox, no del
  código. Sospecha fuerte: `node` en el sandbox es v26.7.0 (homebrew), muy
  por delante de lo que `jamovi-compiler` 0.3.5 (empaquetado con jmvtools
  2.7.26) probablemente soporta. Detalle completo en README.md.
- No probado en la app jamovi real (UI panel, `enable: (mode:...)`
  bindings, render de plots) — pendiente de que el usuario compile.

## Ronda 2 (2026-08-23): compiló bien, feedback de uso real
El usuario compiló con éxito (desktop + docker, vía `tools/install.sh`) y
probó el módulo. Feedback, y lo que cambié en respuesta:

1. Bug de NAMESPACE (`corrInspect::corrInspect` no exportado) → arreglado,
   ver commit `a5c43b3`.
2. ">3 variables da heatmap automático, debería ser una opción aparte" →
   nueva opción `heatmap` (Bool), independiente de `plots`. `plotAllVsAll`
   ahora: 2 vars usa `plots`; >2 vars usa `heatmap`. Ya NO cambia de forma
   solo por el conteo de variables.
3. "Density no hace nada en los plots" → probado standalone (script en
   `.tmp/`, borrado tras confirmar) que `gridExtra::grid.arrange` con
   densidades marginales SÍ dibuja bien fuera de jamovi. Sospecha fuerte:
   el usuario probaba con >2 variables, donde antes se mostraba el heatmap
   (que nunca usa plotDens) — el fix del punto 2 probablemente resuelve
   esto como efecto colateral. Pendiente confirmar con exactamente 2
   variables o en modo ref-vs-resto.
4. "IC95% debería mostrar 3 decimales como r" → `ciText()` en
   corrCompute.R: `%.2f` → `%.3f`.
5. "IC95% no aparece para Spearman/Kendall" (usuario dio un link de Cross
   Validated sobre Spearman) → investigado (WebSearch, CV bloqueó
   WebFetch con 403): Fieller, Hartley & Pearson (1957) recomiendan la
   MISMA corrección Var(z)=0.437/(n-4) sobre el z de Fisher para AMBOS,
   rho de Spearman y tau de Kendall (no solo Spearman, como el usuario
   pensaba al no encontrar nada específico para Kendall). Implementado
   como `fisherZCI()` en corrCompute.R,
   usado en `corrFit()` para method %in% c('spearman','kendall'); Pearson
   sigue usando el CI exacto de `cor.test`. Tests en
   test-corrCompute.R recomputan la fórmula independientemente como
   oráculo (no hay oráculo externo en base R para esto).
6. Rediseño de UI para el modo "una vs. el resto": eliminado el option
   `mode` (List) Y el box `compareVars` por completo. Ahora solo 2 cajas:
   `vars` (Variables) y `refVar` (Variable, opcional). Si `refVar` está
   vacío → allVsAll con `vars`. Si `refVar` tiene una variable → refVsRest,
   comparando contra `setdiff(vars, refVar)` (por si el usuario mete la
   misma variable en ambas cajas). Esto es un cambio de arquitectura
   respecto a la decisión original de la Ronda 1 (2 cajas separadas
   refVar/compareVars) — el usuario pidió específicamente colapsar
   `compareVars` dentro de `vars` y quitar el selector de modo explícito.
   Afecta a.yaml, r.yaml (visible: (mode:...) → visible: false + control
   100% por R vía setVisible, ya que `mode` ya no existe como opción),
   u.yaml (quitado RadioButton de mode y TargetLayoutBox de compareVars;
   refAxis ahora usa `enable: (refVar)` — truthy test sobre un option
   Variable, NO verificado en compilador real, es la mayor incertidumbre
   de este round) y corrinspect.b.R (`.isRefMode()`/`.restVars()`
   reemplazan las referencias a `self$options$mode`/`compareVars`).
   `tools/install.sh` actualizado a la nueva firma de
   `corrInspect::corrInspect(data, vars, refVar=NULL, ...)`.

Borrado `R/corrinspect.h.R` del repo (quedó obsoleto tras cambiar las
opciones y no se pudo regenerar en este sandbox) — se regenera solo en el
próximo `jmvtools::prepare()`/`install()` del usuario.

## Ronda 3 (2026-08-23): diseño aprobado, feedback sobre plots/heatmap + i18n
Usuario: "diseño ok, más simple y igual de funcional." Nuevo feedback:

1. "Scatterplots no muestra ningún plot" → causa real encontrada: nunca
   implementé NADA para `plots` cuando allVsAll tiene >2 variables (solo
   heatmap existía ahí). El usuario casi seguro probó con >2 variables
   (coincide con que "Heatmap sí" funcionaba a la vez). Fix: nueva
   `.drawScatterMatrix()` — matriz de mini-scatters (triángulo inferior =
   scatter+lm+r pequeño, diagonal = nombre de variable, triángulo superior
   en blanco), construida con `gridExtra::grid.arrange(grobs=...)`.
   Probado standalone (script en .tmp/, borrado) con mtcars antes de
   integrar — funciona.
2. Arquitectura de plots separada en DOS Image independientes en vez de
   una sola con lógica mutuamente excluyente: `plotScatter` (gated por
   `plots`: 2 vars → `.drawAnnotatedScatter`, >2 vars → `.drawScatterMatrix`)
   y `plotHeatmap` (gated por `heatmap`, solo >2 vars). Antes compartían
   un único `plotAllVsAll`, lo que hacía imposible mostrar ambos a la vez
   aunque el usuario marcase las dos casillas — bug de diseño corregido.
3. Heatmap mejorable:
   - "solo Pearson, podría ser seleccionable" → nueva opción List
     `heatmapMethod` (pearson/spearman/kendall, default pearson),
     independiente de los checkboxes pearson/spearman/kendall de la tabla.
     `.heatmap()` ahora usa `corrFit()` (antes `stats::cor()` a pelo,
     ignorando el method seleccionado — bug real).
   - "incluir además de r los otros valores... una opción (details)" →
     nueva opción Bool `heatmapDetails`. Cuando está activa, cada celda
     añade las líneas que correspondan de IC95%/p/N/flag, reutilizando
     los checkboxes YA existentes (ci/sig/n/flag) — sin opciones nuevas
     por cada estadístico, tal como pidió el usuario.
4. Multilingüe: `jamovi/i18n/es.po` y `jamovi/i18n/ca.po` creados,
   siguiendo el mismo formato/ubicación que `conttables2xK`
   (jamovi-conttables-2xK/conttables2xK/jamovi/i18n/{es,ca}.po, revisado
   como referencia — NO copiado, es el catálogo entero de jmv y no aplica
   a un módulo nuevo). Traducidos: título/subtítulo del módulo,
   descripción principal, todos los títulos de opciones y de ítems de
   List, labels de agrupación del panel, títulos de tabla/columnas, título
   de los plots (~35 msgid). Reutilicé el wording exacto de jmv donde ya
   existía equivalente (p.ej. "Correlation Coefficients"→"Coeficientes de
   Correlación", igual que corrMatrix/corrPart en su es.po) para
   consistencia terminológica. NO traducidos (límite de alcance,
   mencionado al usuario): los tooltips largos (`description.ui` en
   a.yaml) y las cadenas generadas dinámicamente en R (título de
   tableRefVsRest con el nombre de la variable, `methodLabel()`) — no
   verifiqué el mecanismo de i18n del lado R (¿`jmvcore::.()`? no
   confirmado) y no quise arriesgar el build por eso.
   Las referencias `#:` de cada entrada apuntan al archivo yaml, no a la
   ruta posicional exacta (`ui[N][...]`) que usa el catálogo real de jmv
   — no tengo forma de verificar esos índices sin el compilador
   funcionando, y el `msgid` (no el comentario `#:`) es lo que
   determina la traducción en tiempo de ejecución, así que esto no
   debería afectar a que funcione.

`R/corrinspect.h.R` reapareció sin trackear (el usuario reconstruyó entre
la Ronda 2 y esta) pero quedó desactualizado otra vez tras añadir
heatmapMethod/heatmapDetails — dejado fuera de git de nuevo, se
regenerará en el próximo build.

## Ronda 4 (2026-08-23): scatterplots pairs/matrix, toggles del scatter, heatmap en modo referencia
Pedido del usuario (denso, una sola frase por punto):

1. "Sub-opción para mostrar en formato matrix... o formato pares (como
   sale para referencia), generando todos los pares si no hay referencia."
   → nueva opción `plotsFormat` (List: matrix/pairs, default matrix),
   relevante con >2 variables y sin refVar. Arquitectura: unifiqué el
   Array que antes era solo `plotRefVsRest` (una por variable comparada
   en modo referencia) con el nuevo caso "pares" de allVsAll (una por
   cada par, key="var1|var2") en un único Array `plotPairs` — el
   renderFun `.plotPairs` decide por el formato de la key (con o sin
   "|") si está en modo referencia o en modo pares. Evita duplicar la
   lógica del scatter anotado en dos sitios.
2. "En formato pares, opciones para mostrar: r, p, recta, ecuación de la
   recta." → 3 opciones nuevas (`plotR`, `plotLine`, `plotEquation`,
   todas Bool default TRUE = comportamiento actual sin cambios visibles
   si no se tocan) + reutilizado `sig` (ya existente, "Report p-value")
   para el toggle de p — mismo patrón de reutilización que
   heatmapDetails en la ronda anterior. Aplican a CUALQUIER scatter
   anotado (2 vars, pares, o modo referencia), no solo al nuevo formato
   "pairs".
3. "Alinea el inicio de r y ecuación." → `hjust=-0.05` (valor un poco
   arbitrario) → `hjust=0` (alineación a la izquierda real). Verificado
   visualmente con un PNG standalone antes de integrar.
4. "Elimina densities, no funciona y no hace falta." → opción `plotDens`
   eliminada por completo (a.yaml, u.yaml, r.yaml clearWith, y la rama
   de `gridExtra::grid.arrange` con marginal densities en
   `.drawAnnotatedScatter`). No investigué la causa raíz del "no
   funciona" — el usuario pidió quitarla directamente, no arreglarla.
5. "El heatmap también con una columna para modo referencia." → `.heatmap()`
   ahora soporta refMode: en vez de matriz n×n, genera pairs =
   (refVar, v) para cada v en restVars → una sola columna (var1=refVar),
   n filas. Mismo `heatmapMethod`/`heatmapDetails`. `.plotHeatmap` y
   `.updateVisibility` ya no excluyen refMode.
6. "En modo matrix, aspecto cuadrado del heatmap; la leyenda quita
   espacio, ponla fuera o amplía el tamaño." → añadido
   `ggplot2::coord_fixed()` (celdas cuadradas garantizadas
   independientemente del ancho que ocupe la leyenda) +
   `theme(legend.position='bottom')` (libera espacio horizontal) +
   tamaño de imagen ajustado (+90px de alto para la leyenda). Verificado
   visualmente con PNG standalone (n×n y columna única) antes de
   integrar — ver capturas en la conversación.
7. "En details de heatmap, IC95% a 2 decimales como r." → `ciText()`
   ahora acepta `decimals` (default 3, sin cambiar tabla/scatter);
   `.heatmapCellLabel()` llama `ciText(..., decimals=2)` para que
   coincida con el `%.2f` que ya usa el heatmap para r.

i18n actualizado: quitadas las entradas de "Densities for variables" y
"Plot" (Label genérico, sustituido por "Scatterplots"/"Correlation
heatmap" como Labels propios, que ya tenían entrada); añadidas "Layout",
"Matrix", "Pairs", "Regression line", "Line equation" en es.po/ca.po.

`R/corrinspect.h.R` sigue sin trackear (gitignored desde la ronda 3);
seguirá reapareciendo/desapareciendo con cada build del usuario, es
esperado.

## Ronda 5 (2026-08-23): confirmaciones + factor en refVar + i18n dinámico + estética scatter/heatmap
Usuario confirma: `enable: (refVar)` funciona (ronda 2, ya cerrado) y las
traducciones funcionan (ronda 3, ya cerrado) — quitados de "pendientes".

1. **BUG SIN DIAGNOSTICAR**: "refVar funciona bien, impide que se pueda
   añadir un factor, pues aparece un error." No tengo el texto exacto del
   error. Investigué varias hipótesis (jmvcore::toNumeric fallando en
   factores nominales con etiquetas de texto; alguna diferencia entre
   `type: Variable` singular vs `type: Variables` plural en el schema del
   compilador) pero ninguna explica de forma concluyente un ERROR duro
   (mis guards de `complete.cases`/`length(x)<3` deberían capturar un
   `toNumeric()` que devuelve todo NA sin lanzar excepción). No adiviné
   un fix sin evidencia — pedido al usuario el texto exacto del error en
   la respuesta.
2. "Traducciones... no se usa Pearson's sino 'r de Pearson'." → Esto reveló
   que `methodLabel()` (string generado en R, no en yaml) SÍ es
   traducible: investigué la fuente real de jmvcore instalado
   (`jmvcore:::Analysis$public_methods$translate`,
   `jmvcore:::Options$public_methods$translate`,
   `jmvcore:::createTranslator`) y confirmé que:
   - `self$translate(text)` (método público de cualquier Analysis) es la
     API correcta.
   - Internamente llama `createTranslator(private$.package, private$.lang)`,
     que carga `system.file("i18n/<lang>.json", package=<package>)` — es
     decir, EL MISMO `inst/i18n/<lang>.json` que ya se genera desde
     `jamovi/i18n/*.po`. Un solo catálogo sirve para UI y para backend R.
   - Si el `msgid` no está en el catálogo, `translate()` devuelve el texto
     original sin más (fallback seguro, no hay riesgo de romper nada al
     envolver strings que no estén traducidas).
   Aplicado `self$translate(methodLabel(m))` en `.initTable()` (columna
   `stat` de ambas tablas) y en la leyenda del heatmap
   (`labs(fill=self$translate(methodLabel(method)))`); y
   `self$translate('Correlations')`/`self$translate('vs. others')` para
   el título dinámico de `tableRefVsRest`. Añadidas "Pearson's r"→"r de
   Pearson", "Spearman's rho"→"rho de Spearman" (Kendall's tau-b ya
   existía, mismo string que el título de la opción) y "vs. others"→"vs.
   el resto"/"vs. la resta" en es.po/ca.po.
3. "Las leyendas empiezan justo en el eje, desplázalas al menos 1
   carácter." → `hjust` de la anotación: `0` → `0.02` (scatter anotado) y
   `-0.1` → `0.05` (matriz de scatters, el valor negativo empujaba el
   texto FUERA del panel, no solo pegado al eje).
4. "Aumenta la escala del eje Y un 10-15% para acomodar las leyendas sin
   que tapen puntos" + "el 0 muy alto con mucho espacio en blanco debajo
   cuando no hay negativos, el máximo sí es correcto, pasa con ceros en
   la variable" → mismo fix para ambos: la banda de predicción
   (`predict(..., interval='prediction')`) puede extenderse muy por
   debajo del rango real de los datos (confirmado con un ejemplo
   standalone: datos en [0, 30], banda hasta -13), y ggplot2 expande el
   eje para acomodarla entera. Cambiado a `coord_cartesian(ylim=...)`
   calculado sobre el rango de los DATOS (no de la banda), con margen
   inferior 5% y superior 15% (5% si no hay anotación) — recorta la
   banda visualmente sin afectar el ajuste ni los datos. Verificado
   antes/después con PNG standalone (capturas en la conversación).
5. "Pon color a los plots de dispersión, ejes en negro, puntos en azul
   claro, línea en negro." → colores fijos (ya no derivados de
   `theme$color`/`theme$fill`, que dependían del tema activo de jamovi):
   `pointColour='#5DADE2'` (azul claro), `lineColour='black'`, y
   `theme(axis.text=..., axis.title=..., axis.ticks=element_*(colour=
   'black'))` añadido DESPUÉS de `ggtheme` en la cadena (para que
   sobreescriba, no antes — el orden importa). Aplicado tanto al scatter
   anotado como a los mini-paneles de la matriz. Nota para el usuario:
   esto fuerza negro pase lo que pase con el tema oscuro de jamovi (texto
   de la anotación en sí se dejó como estaba, derivado del tema, para no
   arriesgar legibilidad en modo oscuro — solo ejes se fuerzan a negro,
   que es lo que pidió explícitamente).
6. "La letra de la leyenda del heatmap es muy grande respecto a la barra
   de color... reduce la fuente y aumenta el espacio de la barra." →
   `legend.title`/`legend.text` a tamaño 8/7 (antes heredado del tema,
   más grande) + `guide_colorbar(barwidth=unit(5,'cm'),
   barheight=unit(0.35,'cm'))`. Verificado con PNG standalone antes de
   integrar.

Densities (eliminado la ronda pasada) no se volvió a tocar — el usuario
no lo mencionó esta vez, coherente con que ya no existe.

## Ronda 6 (2026-08-23): diagnóstico del bug de refVar+factor
Usuario dio el texto exacto del error:
```
Error in var(if (is.vector(x) || is.factor(x)) x else as.double(x), na.rm = na.rm):
Calling var(x) on a factor x is defunct.
private$.run() → private$.runAllVsAll() → corrFit(x, y, m, alternative, ciWidth) → stats::sd(y)
```
Causa raíz confirmada probando `jmvcore::toNumeric()` directamente en R
(no adivinado): para un factor NOMINAL de texto, `toNumeric()` lo deja
TAL CUAL (mira si tiene un atributo `"values"` de jamovi; si no hay
conversión numérica sensata, no convierte nada) — comportamiento
correcto de `toNumeric()`, no un bug suyo. El bug era mío: `vars`/`refVar`
tenían `permitted: [numeric, factor]` (copiado de jmv::corrMatrix), así
que jamovi SÍ dejaba arrastrar un factor nominal al panel, y luego
`stats::sd()` en `corrFit()` explotaba con ese factor sin convertir en R
moderno (`var()` en un factor es "defunct" desde hace unas versiones).
Fix: `permitted: [numeric, factor]` → `permitted: [numeric]` en ambas
opciones (a.yaml), y `suggested` ajustado a `[continuous]` (ya no tiene
sentido sugerir "ordinal" si "factor" ni siquiera está permitido). Con
esto jamovi bloquea el factor en el propio panel, como pedía el usuario
("jamovi no debería permitir añadir una variable factor") — no se tocó
el código R (no hace falta blindaje extra en `corrFit()` ya que la vía
de entrada real, el panel, queda cerrada; la función R exportada
`corrInspect()` sigue sin blindar para uso directo desde script, pero
eso está fuera de lo reportado y no se ha añadido complejidad para un
caso no visto).

## Ronda 7 (2026-08-23): dirección del offset, bandas CI/PI opcionales, ejes en matriz
Confirmado por el usuario: recorte del eje Y (Ronda 5) correcto.

1. "El offset de la leyenda debe ser al revés, sumando x." Diagnóstico: con
   `x = -Inf`, `hjust` NO añade separación — es justificación, no padding.
   `hjust=0` pone el borde izquierdo del texto exactamente en el ancla
   (-Inf = borde del panel); subir hjust (lo que hice en la Ronda 5, 0→0.02)
   no crea hueco, solo cambia cuánto texto "debería" quedar a la izquierda
   de un punto que ya es el límite absoluto — sin efecto útil real. Fix
   correcto: usar una coordenada de datos real en vez de `-Inf`
   (`x = min(x) + diff(range(x))*0.02`, `hjust=0`) — un desplazamiento
   genuino, tal como pidió el usuario ("sumando x"). Aplicado en
   `.drawAnnotatedScatter` (2%) y `.drawScatterMatrix` (5%, paneles más
   pequeños). Verificado con PNG standalone antes de integrar.
2. "No quiero la sombra del IC de predicción; que sea opción dibujar IC
   (azul) y predicción (rosa)." La banda de predicción incondicional
   (ligada a `plotLine`) se elimina. Nueva opción `plotPredBand` (Bool,
   default FALSE, "Prediction band", rosa `#F48FB1` — el mismo rosa que
   usa `jamovi-jmvplus::scat.b.R`, buen callback). Reutilizado `ci`
   (ya existente, "Confidence interval") para dibujar TAMBIÉN una banda
   azul de confianza (`predict(..., interval='confidence')`), en vez de
   añadir una opción nueva solo para eso — mismo patrón de reutilización
   que heatmapDetails/scatter-p. Orden de capas: predicción (rosa, más
   ancha) primero, confianza (azul) encima, para que la más estrecha no
   quede tapada. Ambas usan el mismo `ciWidth` ya existente como nivel.
   Verificado con PNG standalone (banda rosa fuera, azul dentro,
   correcto) antes de integrar.
3. "En el formato matriz no se dibujan los ejes." `.drawScatterMatrix`
   usaba `theme_void()` (sin ejes en absoluto). Cambiado a
   `theme_minimal(base_size=6)` + texto/ticks de eje en negro tamaño 5,
   sin grid, con el borde gris que ya tenía. Verificado con PNG
   standalone (ticks y números visibles y legibles a tamaño mini-panel).

## Next Step
El usuario reconstruye y prueba de nuevo. Pendientes arrastradas de
rondas anteriores, sin confirmar todavía:
- Layout "Pairs" con >2 variables sin referencia (Ronda 4).
- heatmap en modo referencia (columna única) (Ronda 4).
- estética del heatmap (leyenda/fuente) a tamaños reales del panel (Ronda 5).
- IC95% de Spearman/Kendall con valores razonables, no solo que aparezcan
  (Ronda 2).
- que el fix del factor en Variables/Reference bloquee de verdad en el
  panel (Ronda 6).
- las bandas CI/PI y el nuevo offset de la leyenda, a tamaños reales de
  panel (nuevo, Ronda 7).
