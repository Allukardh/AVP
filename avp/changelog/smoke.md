# AVP-SMOKE

## v1.4.15 (2026-02-14)
- FIX: normalize changelog (add missing entries, preserve full history)
## v1.4.14 (2026-02-14)
- FIX: reorder changelog entries (strict order compliance)
## v1.4.13 (2026-02-14)
- NOTE: version consumed for governance correction (header/SCRIPT_VER alignment)
## v1.4.12 (2026-02-14)
- CHG: add WARN exit sentinel check (incremental hardening)
## v1.4.11 (2026-02-10)
- FIX: alinhar SCRIPT_VER ao estado atual (inclui gates monotonic/targets)
## v1.4.10 (2026-02-08)
- NOTE: version number skipped involuntarily due to versioning error (no functional change lost)
## v1.4.9 (2026-02-08)
- FIX: BASHISM gate nao reprova local (busybox ash); continua bloqueando declare/typeset/function/source
## v1.4.8 (2026-01-26)
- VERSION: bump patch (pos harden canônico + STRICT defaults)
## v1.4.7 (2026-01-26)
- CHG  : VER gate aceita bloco canônico entre SCRIPT_VER e set -u (PATH/hash) com 1 linha em branco antes/depois
## v1.4.6 (2026-01-20)
- POLISH: dedupe do PATH no bootstrap (higiene; log menor)
## v1.4.5 (2026-01-20)
- POLISH: HELP corrige semantica do --hotfix (EXPECT recomendado; dirty auto-fill; clean warn/best-effort).
## v1.4.4 (2026-01-20)
- POLISH: git_cmd agora blinda pager (core.pager=cat + pager.diff=false + --no-pager) — nunca “limpar tela”.
- POLISH: HELP/docs alinhados ao --hotfix (EXPECT recomendado; dirty=auto-fill; clean=warn/best-effort).
- HOTFIX gate: AVP_SMOKE_EXPECT opcional; auto-fill via git diff --name-only quando dirty; clean=best-effort
## v1.4.2 (2026-01-20)
- FIX  : patch-check volta a ser opcional em --pre/--post/--hotfix (só roda com AVP_SMOKE_PATCH)
## v1.4.1 (2026-01-20)
- HARDEN: --patch-check agora valida parse completo (headers vs "Checking patch")
## v1.4.0 (2026-01-18)
- FEAT : consolida gates novos, auditoria e targets dinamicos como MINOR
- FEAT: modo AUDIT (AVP_SMOKE_AUDIT=1) forca STRICT_VER/STRICT_ORDER e pula exec de gates (POL/ACTION)
- FEAT: DEFAULT_TARGETS agora auto-detecta avp-*.sh + hooks + avp/www/*.asp (ordena se sort existir)
- FEAT: VER gate reforcado: ordem oficial (CHANGELOG -> SCRIPT_VER -> set -u) + STRICT_ORDER (+ modo AUDIT forca)
- FEAT: gate_syntax acumula falhas VER e lista arquivos; AUDIT SUMMARY (contadores) quando AUDIT=1
- POLISH: banner mostra AUDIT/STRICT_* e AUDIT_EFFECTIVE quando auditoria ativa
## v1.3.20 (2026-01-18)
- POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
## v1.3.19 (2026-01-18)
- FIX : HOTFIX EXPECT nao falha quando nao ha dirty tracked (tree limpa); apenas WARN.
## v1.3.18 (2026-01-18)
- TUNE: PROBE ACTION: token_get sem token agora pode ser SKIP limpo (mesmo em strict),
## v1.3.17 (2026-01-18)
- POLISH: bump+changelog (higiene operacional).
## v1.3.16 (2026-01-18)
- FIX : --patch-check agora aceita patch via AVP_SMOKE_PATCH sem args (set -u safe).
## v1.3.15 (2026-01-18)
- FIX : --patch-check não falha quando não há args; troca "${#}" por "$#" (set -u safe).
## v1.3.14 (2026-01-16)
- FIX : remove bloco legado do banner (pre-init) que quebrava com set -u (_smoke_* unset).
## v1.3.13 (2026-01-16)
- TUNE: banner agora mostra REPO=<rev-parse --short=12> DIRTY=<0|1> FILEHASH=<git hash-object>.
- DROP: remove smoke_hash (sha256/md5/cksum) — usa git como fonte unica.
## v1.3.12 (2026-01-15)
- FIX : banner sempre imprime HASH=... ou HASH=unavailable (resolve path via ./file e fallback ROOT(/jffs/scripts)).
## v1.3.11 (2026-01-15)
- ADD : banner de auditoria (SCRIPT_VER + file + HASH best-effort).
- NOTE: hash usa sha256sum/md5sum; fallback cksum (BusyBox).
## v1.3.10 (2026-01-15)
- TUNE: Probes POL/ACTION agora são BEST-EFFORT por padrão (WARN ao falhar), evitando bloquear patch por estado runtime.
## v1.3.9 (2026-01-15)
- FIX : BASHISM gate agora ignora POSIX charclass ([[:...:]]) e evita falso-positivo em sed/awk.
## v1.3.8 (2026-01-15)
- DEFAULTS: MAXLEN agora = 200 (anti-wrap recomendado); LEN_STRICT segue WARN (0)
- CHANGE : --hotfix prefere AVP_SMOKE_EXPECT; se dirty auto-preenche via git diff --name-only; se clean apenas WARN (best-effort)
- ADD    : AVP_SMOKE_BASHISM_STRICT=1 (modo estrito opcional; default = normal)
- TUNE   : ordem dos gates no --post/--hotfix: git diff --check mais cedo (reduz retrabalho)
- TUNE   : mensagens mais cirúrgicas para orientar o operador (pre/post/hotfix)
## v1.3.7 (2026-01-15)
- FIX : SCRIPT_VER realmente definido no arquivo (após set -u)
## v1.3.6 (2026-01-15)
- ADD : SCRIPT_VER no smoke (padrao DTP)
- FIX : gate_crlf refeito (detecção robusta de CR em BusyBox awk)
- ADD : gate_shebang (#!/bin/sh) para alvos shell
- ADD : gate_bashisms (heurística) para capturar tokens não-POSIX
- ADD : gate_line_len (anti-wrap) com limiar configurável
## v1.3.5 (2026-01-15)
- ADD : AVP_SMOKE_ROOT + autodetecção de repo (fallback útil para snapshots/tar)
- FIX : gate_perms vira zero-intervenção por padrão (valida +x; corrige só se AVP_SMOKE_FIX_PERMS=1)
- ADD : gates de higiene de texto (CRLF/BOM) para .sh/.asp (catch precoce de conversão de linha)
- TUNE: mensagens de erro agora apontam envs (AVP_SMOKE_ROOT / AVP_SMOKE_FIX_PERMS)
## v1.3.4 (2026-01-15)
- FIX : suite padrão agora inclui TODOS os avp-*.sh do topo (inclui avp-lib.sh/avp-backup.sh/avp-diag.sh).
## v1.3.3 (2026-01-15)
- ADD : alvos (targets) por argumento/env: permite rodar gates gerais ou focar em arquivos específicos (sh/asp).
- ADD : gate opcional de patch (git apply --check) via modo --patch-check ou AVP_SMOKE_PATCH.
- ADD : gate git diff --check em --post/--hotfix (pega whitespace/EOF) + opção de estrito por env.
- ADD : validação opcional de versão (header Version vs SCRIPT_VER) para scripts alvo (warn por padrão).
- TUNE: bootstrap reforçado (PATH + no-pager) e lista padrão inclui services-start/post-mount.
## v1.3.2 (2026-01-07)
- CHANGE: substitui o modo --pre-hotfix pelo modo --hotfix (bypass explícito do baseline limpo)
- TUNE  : textos/help agora referenciam --hotfix (e continuam orientando --post quando já está editando)
## v1.3.1 (2026-01-07)
- FIX: implementa EXPECT sem depender de awk; comparação por lista (ordem-insensível se sort existir)
- TUNE: mensagens de erro mais claras para --pre/--post/--hotfix
## v1.3.0 (2026-01-07)
- ADD: modo --hotfix (bypass explícito do baseline limpo) + EXPECT opcional p/ arquivos sujos
- TUNE: mensagens orientando --post quando a árvore já está suja por edição em andamento
## v1.2.0 (2026-01-07)
- ADD: gate do avp.asp (WEBUI_VER/pill): header Version vs const WEBUI_VER (+ sanity changelog)
- TUNE: mantém bootstrap robusto (PATH + binscan real) e gates POL/ACTION
## v1.1.0 (2026-01-07)
- FIX: bootstrap robusto (PATH + busca por binários reais) p/ cron/CGI/non-interactive
- ADD: gates --pre/--post com foco em baseline limpo, sintaxe e JSON parseável (se jq existir)
- ADD: prova “rápida” de POL/ACTION (somente JSON parseável + contratos mínimos)
## v1.0.0 (2026-01-06)
- ADD: initial release

## v2.0.0 (2026-02-17)
- CHG: smoke Python-first (V2-only), sem changelog interno
- CHG: delega governança V2 ao avp-meta --check por alvo
- ADD: gates rápidos: git diff --check (worktree+staged), sh -n, py_compile
