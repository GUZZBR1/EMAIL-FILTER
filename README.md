# Email Filter

## 🎯 Objetivo Geral
O Email Filter é uma aplicação web projetada para conectar múltiplas contas do Gmail e facilitar a localização de e-mails e anexos por meio de um sistema de filtros visuais avançados, eliminando a necessidade de dominar a sintaxe de busca do Gmail e oferecendo uma visão consolidada de arquivos.

## 📍 Estado Atual
**Fundação do monorepo iniciada; aplicações ainda não inicializadas.**
A visão do produto, requisitos funcionais, não-funcionais e a arquitetura de alto nível foram definidos e consolidados.

## 📂 Estrutura do Monorepo
O projeto utiliza uma estrutura modular para separar as responsabilidades de execução e contratos:

- `apps/web`: Frontend em Next.js com TypeScript.
- `apps/server`: API de backend em Python com FastAPI.
- `apps/worker`: Processo assíncrono para execução de Search Jobs.
- `packages/contracts`: Definições de API e contratos compartilhados.
- `supabase/`: Configurações de banco de dados e migrations PostgreSQL.
- `scripts/`: Ferramentas auxiliares de desenvolvimento e operação.
- `docs/`: Documentação oficial do projeto.

## 🚀 Principais Capacidades
- **Multi-Account Search**: Pesquisa simultânea em várias contas Gmail vinculadas.
- **Visual Filtering**: Interface para criação de filtros complexos (remetente, data, palavras-chave).
- **Attachment Gallery**: Localização de anexos por nome, extensão, tipo e tamanho com visualização independente.
- **Async Jobs**: Processamento de buscas em background com acompanhamento de status e cancelamento.
- **Secure Proxy**: Download de anexos via backend para proteção de credenciais.

## 🛠 Stack Tecnológica Planejada
- **Frontend**: Next.js com TypeScript.
- **Backend**: FastAPI com Python.
- **Banco de Dados**: Supabase / PostgreSQL.
- **Autenticação**: Google OAuth 2.0.
- **API**: Gmail API.

## 📖 Documentação Oficial
A especificação detalhada do projeto encontra-se em:
👉 [docs/EMAIL_FILTER_SPECIFICATION.md](docs/EMAIL_FILTER_SPECIFICATION.md)

O plano de implementação técnica está disponível em:
👉 [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)

---

⚠️ **Atenção**: O desenvolvimento do código da aplicação ainda não foi iniciado. O projeto encontra-se rigorosamente na etapa de fundação e especificação.

## 🗓️ Próximos Passos
1. Planejamento técnico detalhado (Design de API e Banco de Dados).
2. Implementação da fundação do monorepo (Concluído).
3. Implementação do fluxo de autenticação e perfis.
4. Integração com a Gmail API.
5. Desenvolvimento do motor de busca e galeria de anexos.
6. Estratégia de testes e deploy.
