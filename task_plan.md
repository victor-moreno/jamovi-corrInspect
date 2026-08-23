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

## Next Step
El usuario compila (`jmvtools::prepare("corrInspect"); jmvtools::install("corrInspect")`)
en su entorno habitual y prueba en jamovi real. Si aparecen errores de
compilación de yaml o de R en tiempo de ejecución, iterar aquí sobre esos
mensajes concretos.
