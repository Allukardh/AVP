# AVP-APPLY

## v1.0.26 (2026-02-15)
-   * CHANGE: baseline policy alinhada com avp-tag.sh (status --porcelain)
## v1.0.25 (2026-02-14)
-   * FEATURE: registra contexto 3B apos patch aplicado com sucesso,
-     criando /tmp/avp_last_apply.ok e /tmp/avp_last_apply_files.list
## v1.0.24 (2026-01-26)
-   * VERSION: bump patch (pos harden canônico)
## v1.0.23 (2026-01-21)
-   * FIX   : RC cirurgico: separa apply --check (RC=14) de strict_ws (RC=13); apply continua RC=15.
## v1.0.22 (2026-01-20)
-   * POLISH: remove duplicidade de _spc/log no bloco SMOKE --patch-check; log fica coerente com SKIP e fluxo fica deterministico.
## v1.0.21 (2026-01-20)
-   * FIX   : AVP_APPLY_SMOKE_PATCHCHECK=0 agora pula de fato o bloco do smoke --patch-check (evita RC=21 quando toggle=0 e permite RC=13 no apply --check).
## v1.0.20 (2026-01-20)
-   * CONTRACT: toggle AVP_APPLY_SMOKE_PATCHCHECK=0 para pular smoke --patch-check e deixar RC=13 representar falha do git apply --check no APPLY.
## v1.0.19 (2026-01-20)
-   * CONTRACT: separa RC do SMOKE vs PATCH (SMOKE pre=20, patch-check=21, post=22; PATCH inexistente=11, sem leitura=12, --check=13).
## v1.0.18 (2026-01-20)
-   * CONTRACT: RC dedicado p/ patch inexistente (11), sem leitura (12) e git apply --check falha (13).
## v1.0.17 (2026-01-20)
-   * POLISH: bloqueia rename/copy em patches (gate antes do apply) para evitar repo dirty.
## v1.0.16 (2026-01-20)
-   * POLISH: gate duro de paths no patch (bloqueia b/tmp, /tmp, path absoluto e ../) antes do smoke/apply (RC=17).
-   * POLISH: mantém apply determinístico: recusa patch suspeito (não normaliza paths automaticamente).
## v1.0.15 (2026-01-20)
-   * FIX   : HOTFIX auto-fill do AVP_SMOKE_EXPECT (usa dirty-files do git diff --name-only); se vazio, segue best-effort.
-   * POLISH: padroniza prova de diff sem pager (usar --no-index + --stat em arquivo quando preciso).
-   * TEST  : T20 (patch aplicavel) + T19B (hotfix/dirty) cobrindo RC=10 vs RC=12.
## v1.0.14 (2026-01-20)
-   * FIX   : baseline DIRTY agora aborta cedo (sem smoke --post em DIRTY; --hotfix e o unico bypass).
-   * POLISH: STRICT_WS usa log() + git --no-pager/cor off + exit code especifico.
-   * POLISH: exit codes distintos: strict_ws=13, check=14, apply=15.
## v1.0.13 (2026-01-19)
-   * HARDEN: aborta apply quando baseline DIRTY (permitido somente com --hotfix)
## v1.0.12 (2026-01-19)
-   * FIX   : NORMALIZE_PERMS agora força chmod 755 (evita 777 por umask/attrs e padroniza estado final).
## v1.0.11 (2026-01-19)
-   * ADD   : NORMALIZE_PERMS apos git apply (previne perda de +x por efeitos colaterais de /tmp/umask/patch).
-   * ADD   : AVP_APPLY_FIX_PERMS=1 (default) e AVP_APPLY_PERMS_SKIP (default: avp-lib.sh).
## v1.0.10 (2026-01-18)
-   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
## v1.0.9 (2026-01-17)
-   * FIX   : baseline auto: repo limpo => smoke --pre; repo DIRTY => smoke --post.
-   * NOTE  : evita abort do apply em repo sujo (o smoke --pre recusa DIRTY por design).
## v1.0.8 (2026-01-17)
-   * POLISH: alinha estrutura ao padrao do ENG (1 shebang/header/changelog/SCRIPT_VER), remove duplicatas e restaura historico.
## v1.0.7 (2026-01-17)
-   * FIX   : rebuild canonico (shebang+header+changelog+env harden) e remove blocos duplicados que quebravam o fluxo.
-   * POLISH: padroniza SCRIPT_VER e remove espacos/linhas em branco fora do padrao.
## v1.0.6 (2026-01-17)
-   * NOTE  : versao consumida durante iteracao/higiene operacional (sem registro confiavel para detalhar).
## v1.0.5 (2026-01-17)
-   * POLISH: header+changelog no topo; remove BOOTSTRAP vazio; limpa espacos apos SCRIPT_VER.
## v1.0.4 (2026-01-17)
-   * FIX   : remove WARN legado de git; BOOTSTRAP nao duplica env; PATCH_HASH_OBJECT via git() wrapper.
## v1.0.3 (2026-01-17)
-   * FIX   : env harden no topo + remove WARN falso de git; garante wrapper git() desde o inicio.
## v1.0.2 (2026-01-17)
-   * FIX   : env harden nao depende de log/die/ts; precheck de git define git() (falha cedo).
## v1.0.1 (2026-01-17)
-   * FIX   : detecta git (caminho real) + forca PATH canonico; remove WARN falso.
## v1.0.0 (2026-01-17)
-   * ADD   : runner de aplicacao de patch com logs persistentes (resistente a "session disconnected")
-   * ADD   : integra smoke --pre + --patch-check + --post e git apply --check/apply
-   * ADD   : modo background default + --fg opcional
- =============================================================


## v2.0.0 (2026-02-17)
- CHG: migrate to Python-first V2-only (external changelog; no internal CHANGELOG block)
