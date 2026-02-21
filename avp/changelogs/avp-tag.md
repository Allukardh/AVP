# CHANGELOG — AVP-TAG

## v1.0.9 (2026-02-21)
- tratamento amigável para tag local existente sem remoto (mensagem clara e publicação via --publish)
## v1.0.8 (2026-02-21)
- FIX: valida release via changelog externo (avp/changelogs/<script>.md) no mini-check de rel/*
- DROP: remove validação legada de CHANGELOG embutido no .sh e check de CHANGELOG raiz
## v1.0.7 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-tag.md
- CHG: remove bloco CHANGELOG embutido do script
## v1.0.6 (2026-02-15)
- CHG: rel/* publica por padrão (SSOT) — use --no-publish para desligar
- ADDED: --help/-h + mensagem explícita quando publish estiver desligado
- FIX: remove duplicidade de parse de args e limpa “feiura” estrutural
## v1.0.5 (2026-02-15)
- ADDED: flag --publish (ou AVP_TAG_PUBLISH=1) para publicar SSOT main + tag
- ADDED: mini-checklist (main + diff --check + rel: Version/SCRIPT_VER/CHANGELOG vs tag)
## v1.0.4 (2026-02-14)
- CHG: working tree validation agora usa git status --porcelain (inclui untracked)
## v1.0.3 (2026-02-14)
- ADDED: validação SCRIPT_VER vs tag rel
- FIXED: variável ${TAG} -> ${tag}
- ADDED: validação opcional CHANGELOG externo
## v1.0.2 (2026-02-14)
- CHG: incremental governance guards (working tree, duplicate tag, commit check)
## v1.0.1 (2026-02-08)
- FIX: git show usa --no-pager (evita pager/less no Merlin/SSH)
- FIX: padroniza header Version e SCRIPT_VER (sem aspas)
## v1.0.0 (2026-01-27)
- initial (tag convention enforcement)
