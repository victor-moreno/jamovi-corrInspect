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
