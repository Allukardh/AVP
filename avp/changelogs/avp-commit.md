# CHANGELOG — AVP-COMMIT

## v1.0.14 (2026-02-21)
- POLISH: pre-gate do commit normaliza changelog .md apenas dos avp/bin/*.sh no escopo
- CHG: recarrega CHANGED após md hygiene para incluir avp/changelogs/*.md gerados pela higiene
## v1.0.13 (2026-02-21)
- CHG: valida versão atual no changelog externo (avp/changelogs/<script>.md) para arquivos .sh
- ADD: helpers internos para resolver caminho do changelog externo e ler primeira versão do .md
- TUNE: alinhamento com modelo de CHANGELOG externalizado
## v1.0.12 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-commit.md
- CHG: remove bloco CHANGELOG embutido do script
## v1.0.11 (2026-02-15)
- FIX: gate exit 0 só valida scripts estruturais quando alterados (CHANGED)
- FIX: ultimo comando executavel ignora comentarios e linhas em branco
## v1.0.11 (2026-02-15)
- CHG: remove SMOKE interno; SMOKE fica no WOPU (pre/post)
- CHG: remove auto-checkpoint e push; publicacao passa a ser do avp-tag.sh (SSOT main)
- CHG: avp-commit.sh agora faz apenas gate + commit local
## v1.0.10 (2026-02-15)
- FIX: HEADER_VER encontra token vX.Y.Z via awk (independe de ":")
## v1.0.9 (2026-02-15)
- FIX: HEADER_VER agora encontra token vX.Y.Z (independe de ":")
## v1.0.8 (2026-02-15)
- FIX: HEADER_VER extrai vX.Y.Z mesmo com "# Version : ..."
## v1.0.7 (2026-02-15)
- FIX: parse HEADER_VER robusto (captura vX.Y.Z mesmo com ":")
## v1.0.6 (2026-02-15)
- FIX: parse HEADER_VER robusto (ignora ":")
## v1.0.5 (2026-02-15)
- FIX: baseline gate permite staged/unstaged; bloqueia apenas untracked
- FIX: CHANGED inclui staged + unstaged (sort -u)
- FIX: contagem de remocoes inclui cached + working tree
- FIX: git add usa -A para capturar deletions
## v1.0.4 (2026-02-15)
- CHANGE: baseline policy alinhada com avp-tag.sh (status --porcelain)
## v1.0.3 (2026-02-15)
- HARDEN: validacao robusta do ultimo exit 0 (ignora linhas em branco finais)
## v1.0.2 (2026-02-15)
- FIX: baseline gate real (bloqueia repo DIRTY)
- FIX: validacao robusta de CHANGELOG
- FIX: determinismo 3B com ordenacao
- FIX: validacao segura do ultimo exit 0
- FIX: auto-checkpoint antes do push
## v1.0.1 (2026-02-15)
- ADD: auto-checkpoint para scripts estruturais (Modelo B)
- ADD: gate unificado para 3A e 3B
- ADD: valida governança (Version/SCRIPT_VER/CHANGELOG)
- ADD: bloqueio multi .sh sem --allow-multi
- ADD: bloqueio >20 linhas removidas sem --allow-large-removal
- ADD: valida ultimo exit em scripts estruturais
- ADD: valida determinismo no modo 3B
## v1.0.0 (2026-02-14)
- ADD: versao inicial
