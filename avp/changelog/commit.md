# AVP-COMMIT
## v2.0.2 (2026-02-18)
- FIX: restore validity (python) — remove SyntaxError newline-in-string + bump v2.0.2 (2026-02-18)
Histórico importado do legado `avp-commit.sh` (SSOT origin/main).
## v2.0.1 (2026-02-18)
- FIX: define GIT_BIN e META_BIN (NameError fatal) + sanity repo
- ADD: git diff --check (worktree + staged) antes do commit
- CHG: meta gate exige avp-meta executável e usa cwd determinístico
## v1.0.0 (2026-02-14)
- ADD: versao inicial
## v1.0.1 (2026-02-15)
- ADD: auto-checkpoint para scripts estruturais (Modelo B)
- ADD: gate unificado para 3A e 3B
- ADD: valida governança (Version/SCRIPT_VER/CHANGELOG)
- ADD: bloqueio multi .sh sem --allow-multi
- ADD: bloqueio >20 linhas removidas sem --allow-large-removal
- ADD: valida ultimo exit em scripts estruturais
- ADD: valida determinismo no modo 3B
## v1.0.2 (2026-02-15)
- FIX: baseline gate real (bloqueia repo DIRTY)
- FIX: validacao robusta de CHANGELOG
- FIX: determinismo 3B com ordenacao
- FIX: validacao segura do ultimo exit 0
- FIX: auto-checkpoint antes do push
## v1.0.3 (2026-02-15)
- HARDEN: validacao robusta do ultimo exit 0 (ignora linhas em branco finais)
## v1.0.4 (2026-02-15)
- CHANGE: baseline policy alinhada com avp-tag.sh (status --porcelain)
## v1.0.5 (2026-02-15)
- FIX: baseline gate permite staged/unstaged; bloqueia apenas untracked
- FIX: CHANGED inclui staged + unstaged (sort -u)
- FIX: contagem de remocoes inclui cached + working tree
- FIX: git add usa -A para capturar deletions
## v1.0.6 (2026-02-15)
- FIX: parse HEADER_VER robusto (ignora ":")
## v1.0.7 (2026-02-15)
- FIX: parse HEADER_VER robusto (captura vX.Y.Z mesmo com ":")
## v1.0.8 (2026-02-15)
- FIX: HEADER_VER extrai vX.Y.Z mesmo com "# Version : ..."
## v1.0.9 (2026-02-15)
- FIX: HEADER_VER agora encontra token vX.Y.Z (independe de ":")
## v1.0.10 (2026-02-15)
- FIX: HEADER_VER encontra token vX.Y.Z via awk (independe de ":")
## v1.0.11 (2026-02-15)
- CHG: commit gate delega governança V2 ao avp-meta --check (SSOT)
- CHG: remove dependência de CHANGELOG interno para validação
## v2.0.0 (2026-02-17)
- CHG: rewrite Python-first do commit gate (avp/bin/avp-commit) — V2-only
- CHG: governança SSOT delegada ao avp-meta --check (header/SCRIPT_VER/changelog externo)
- DROP: validação por CHANGELOG interno (legado .sh)
## v1.0.0 (2026-02-14)
- ADD: versao inicial
## v1.0.1 (2026-02-15)
- ADD: auto-checkpoint para scripts estruturais (Modelo B)
- ADD: gate unificado para 3A e 3B
- ADD: valida governança (Version/SCRIPT_VER/CHANGELOG)
- ADD: bloqueio multi .sh sem --allow-multi
- ADD: bloqueio >20 linhas removidas sem --allow-large-removal
- ADD: valida ultimo exit em scripts estruturais
- ADD: valida determinismo no modo 3B
## v1.0.2 (2026-02-15)
- FIX: baseline gate real (bloqueia repo DIRTY)
- FIX: validacao robusta de CHANGELOG
- FIX: determinismo 3B com ordenacao
- FIX: validacao segura do ultimo exit 0
- FIX: auto-checkpoint antes do push
## v1.0.3 (2026-02-15)
- HARDEN: validacao robusta do ultimo exit 0 (ignora linhas em branco finais)
## v1.0.4 (2026-02-15)
- CHANGE: baseline policy alinhada com avp-tag.sh (status --porcelain)
## v1.0.5 (2026-02-15)
- FIX: baseline gate permite staged/unstaged; bloqueia apenas untracked
- FIX: CHANGED inclui staged + unstaged (sort -u)
- FIX: contagem de remocoes inclui cached + working tree
- FIX: git add usa -A para capturar deletions
## v1.0.6 (2026-02-15)
- FIX: parse HEADER_VER robusto (ignora ":")
## v1.0.7 (2026-02-15)
- FIX: parse HEADER_VER robusto (captura vX.Y.Z mesmo com ":")
## v1.0.8 (2026-02-15)
- FIX: HEADER_VER extrai vX.Y.Z mesmo com "# Version : ..."
## v1.0.9 (2026-02-15)
- FIX: HEADER_VER agora encontra token vX.Y.Z (independe de ":")
## v1.0.10 (2026-02-15)
- FIX: HEADER_VER encontra token vX.Y.Z via awk (independe de ":")
## v1.0.11 (2026-02-15)
- CHG: commit gate delega governança V2 ao avp-meta --check (SSOT)
- CHG: remove dependência de CHANGELOG interno para validação
## v2.0.0 (2026-02-17)
- CHG: rewrite Python-first do commit gate (avp/bin/avp-commit) — V2-only
- CHG: governança SSOT delegada ao avp-meta --check (header/SCRIPT_VER/changelog externo)
- DROP: validação por CHANGELOG interno (legado .sh)
