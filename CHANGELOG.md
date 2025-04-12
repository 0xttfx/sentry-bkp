# Changelog

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-04-11

### Adicionado
- Interface interativa para seleção de backups no script de restore
- Opções de linha de comando para ambos os scripts:
  - `-d, --directory`: Especifica diretório de backup/restore
  - `-l, --list`: Lista backups existentes (apenas backup)
  - `-h, --help`: Mostra ajuda
- Validação rigorosa de inputs do usuário
- Proteção contra injeção de comandos
- Verificação de integridade dos arquivos
- Cálculo e registro do tamanho total do backup
- Sistema de logs aprimorado com timestamps e níveis
- Tratamento seguro de credenciais
- Limpeza de dados sensíveis nos logs
- Verificação de espaço em disco
- Melhor tratamento de erros do PostgreSQL
- Verificação de sucesso em todas as operações críticas

### Melhorado
- Organização do código em funções modulares
- Mensagens de log mais detalhadas e informativas
- Validações mais robustas
- Tratamento de erros mais abrangente
- Documentação no README.md
- Interface do usuário mais amigável
- Verificação de permissões mais rigorosa
- Sistema de backup mais confiável
- Processo de restore mais seguro

### Corrigido
- Problemas de permissão em arquivos de log
- Validação de inputs do usuário
- Tratamento de erros em operações críticas
- Verificação de integridade dos backups
- Limpeza de recursos em caso de falha

## [1.0.0] - 2024-04-10

### Adicionado
- Script de backup inicial (`sentry-backup.sh`)
- Script de restore inicial (`sentry-restore.sh`)
- Sistema básico de logs
- Backup de volumes Docker
- Backup do PostgreSQL via pg_dumpall
- Backup parcial JSON do Sentry
- Documentação básica no README.md

[1.1.0]: https://github.com/0xttfx/sentry-bkp/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/0xttfx/sentry-bkp/releases/tag/v1.0.0 
