# Sentry Backup and Restore Tools

Este projeto fornece um conjunto de ferramentas para backup e restore completo de instâncias self-hosted do Sentry. Os scripts foram desenvolvidos seguindo as melhores práticas de shell scripting(eu acho...rs) e incluem tratamento de erros robusto, logging detalhado e validações abrangentes.

## Índice

- [Visão Geral](#-visão-geral)
- [Requisitos](#-requisitos)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Funcionalidades](#-funcionalidades)
- [Como Usar](#-como-usar)
- [Arquivos de Log](#-arquivos-de-log)
- [Tratamento de Erros](#-tratamento-de-erros)
- [Boas Práticas Implementadas](#-boas-práticas-implementadas)
- [Segurança](#-segurança)
- [Manutenção](#-manutenção)
- [Licença](#-licença)
- [Contribuições](#-contribuições)

## Visão Geral

O projeto consiste em dois scripts principais:

1. `sentry-backup.sh`: Realiza backup completo da instância Sentry
2. `sentry-restore.sh`: Restaura uma instância Sentry a partir de um backup

Os scripts foram desenvolvidos para a versão 25.3.0 do Sentry self-hosted e incluem:
- Backup de volumes Docker
- Backup do PostgreSQL via pg_dumpall
- Backup parcial JSON do Sentry
- Sistema de logs detalhado
- Tratamento de erros robusto
- Interface interativa para seleção de backups
- Opções de linha de comando flexíveis
- Validação rigorosa de inputs

## Requisitos

- Docker e Docker Compose instalados
- Acesso root ou sudo para execução dos scripts
- Espaço em disco suficiente para armazenar os backups
- Permissões adequadas nos diretórios de backup
- Bash 4.0 ou superior (para suporte a arrays)

## Estrutura do Projeto

```
sentry-bkp/
├── sentry-backup.sh    # Script de backup
├── sentry-restore.sh   # Script de restore
└── README.md          # Documentação
```

## ⚙️ Funcionalidades

### Backup (`sentry-backup.sh`)

1. **Backup Parcial JSON**
   - Exporta dados de baixo volume do Sentry
   - Inclui configurações, usuários, organizações, etc.

2. **Backup PostgreSQL**
   - Realiza dump completo do banco de dados
   - Utiliza pg_dumpall para backup lógico
   - Comprime o dump para economia de espaço
   - Obtém credenciais de forma segura

3. **Backup de Volumes**
   - Backup de volumes críticos:
     - sentry-data
     - sentry-postgres
     - sentry-redis
     - sentry-zookeeper
     - sentry-kafka
     - sentry-clickhouse
     - sentry-symbolicator
   - Backup de volumes específicos do projeto
   - Verificação de integridade dos arquivos

4. **Manifesto de Backup**
   - Cria arquivo com informações do backup
   - Inclui timestamp, versão e lista de arquivos
   - Calcula e registra o tamanho total do backup

5. **Interface Interativa**
   - Permite especificar diretório de backup
   - Lista backups existentes
   - Opções via linha de comando:
     - `-d, --directory`: Especifica diretório de backup
     - `-l, --list`: Lista backups existentes
     - `-h, --help`: Mostra ajuda

### Restore (`sentry-restore.sh`)

1. **Validação de Backup**
   - Verifica existência dos arquivos necessários
   - Valida permissões e acessibilidade
   - Verifica integridade dos arquivos

2. **Restauração de Volumes**
   - Restaura todos os volumes do backup
   - Mantém a estrutura original
   - Remove volumes existentes antes da restauração
   - Verifica sucesso da restauração

3. **Restauração do PostgreSQL**
   - Restaura o dump do banco de dados
   - Mantém integridade dos dados
   - Obtém credenciais de forma segura
   - Verifica sucesso da restauração

4. **Restauração JSON**
   - Importa dados do backup parcial
   - Restaura configurações e metadados
   - Verifica sucesso da importação

5. **Interface Interativa**
   - Lista backups disponíveis
   - Permite seleção do backup a restaurar
   - Validação de inputs do usuário
   - Opções via linha de comando:
     - `-d, --directory`: Especifica diretório de backups
     - `-h, --help`: Mostra ajuda

## Como Usar

### Backup

```bash
# Dar permissão de execução ao script
chmod +x sentry-backup.sh

# Executar backup com diretório padrão (/backup/sentry)
./sentry-backup.sh

# Especificar diretório de backup
./sentry-backup.sh -d /caminho/para/backup

# Listar backups existentes
./sentry-backup.sh -l

# Mostrar ajuda
./sentry-backup.sh -h
```

### Restore

```bash
# Dar permissão de execução ao script
chmod +x sentry-restore.sh

# Executar restore (interface interativa)
./sentry-restore.sh

# Especificar diretório de backups
./sentry-restore.sh -d /caminho/para/backups

# Mostrar ajuda
./sentry-restore.sh -h
```

## Arquivos de Log

### Backup
- `backup.log`: Log principal do processo de backup
  - Timestamp em cada entrada
  - Nível de log (INFO/ERROR)
  - Mensagens detalhadas
- `error.log`: Log específico para erros
  - Stack traces quando disponíveis
  - Códigos de erro
  - Mensagens de erro detalhadas

### Restore
- `restore.log`: Log principal do processo de restore
  - Timestamp em cada entrada
  - Nível de log (INFO/ERROR)
  - Progresso da restauração
- `restore-error.log`: Log específico para erros durante o restore
  - Stack traces quando disponíveis
  - Códigos de erro
  - Mensagens de erro detalhadas

## Tratamento de Erros

Os scripts incluem:
- Verificação de dependências (Docker, Docker Compose)
- Validação de permissões de arquivos e diretórios
- Tratamento de falhas em cada etapa
- Logs detalhados de erros
- Cleanup em caso de falha
- Validação rigorosa de inputs do usuário
- Verificação de integridade de arquivos
- Tratamento de erros do PostgreSQL
- Validação de credenciais
- Verificação de espaço em disco

## ✅ Boas Práticas Implementadas

1. **Shell Scripting**
   - Uso de `set -euo pipefail`
   - Funções modulares e reutilizáveis
   - Variáveis locais
   - Código limpo e organizado
   - Comentários explicativos
   - Nomes descritivos de variáveis e funções

2. **Logging**
   - Sistema de logs estruturado
   - Timestamps em todas as entradas
   - Níveis de log (INFO/ERROR)
   - Arquivos separados para erros
   - Mensagens claras e informativas
   - Logs de progresso detalhados

3. **Validações**
   - Verificação de comandos disponíveis
   - Validação de arquivos e diretórios
   - Verificação de permissões
   - Validação de credenciais
   - Validação de inputs do usuário
   - Verificação de integridade de arquivos
   - Validação de espaço em disco

4. **Segurança**
   - Tratamento seguro de credenciais
   - Verificação de permissões
   - Validação rigorosa de inputs
   - Proteção contra injeção de comandos
   - Logs separados para auditoria
   - Limpeza de dados sensíveis

## 🔒 Segurança

- Credenciais do PostgreSQL são obtidas de forma segura
- Permissões de arquivos são verificadas
- Erros são tratados sem expor informações sensíveis
- Logs são mantidos separados para auditoria
- Validação rigorosa de inputs do usuário
- Proteção contra injeção de comandos
- Verificação de integridade dos arquivos
- Limpeza de dados sensíveis nos logs

## 🔧 Manutenção

### Atualizações
Para atualizar os scripts:
1. Faça backup dos scripts existentes
2. Substitua pelos novos
3. Verifique as permissões
4. Teste em ambiente de desenvolvimento
5. Verifique a compatibilidade com novas versões do Sentry

### Monitoramento
- Verifique os logs regularmente
- Monitore o espaço em disco
- Mantenha backups antigos organizados
- Revise periodicamente as permissões
- Verifique a integridade dos backups
- Monitore o uso de recursos durante backup/restore

## Licença

Este projeto é distribuído sob a licença BSD 3-Clause. Veja o arquivo [LICENSE.md](LICENSE.md) para mais detalhes.

## 🤝 Contribuições

Contribuições são bem-vindas! Por favor, siga estas etapas:
1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

### Diretrizes para Contribuição
- Mantenha o estilo de código consistente
- Adicione testes para novas funcionalidades
- Atualize a documentação conforme necessário
- Siga as boas práticas de shell scripting
- Inclua logs detalhados para novas funcionalidades 
