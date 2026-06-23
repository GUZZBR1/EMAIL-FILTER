# Email Filter

## 🎯 Objetivo Geral
O Email Filter é uma aplicação web projetada para conectar múltiplas contas do Gmail e facilitar a localização de e-mails e anexos por meio de um sistema de filtros visuais avançados, eliminando a necessidade de dominar a sintaxe de busca do Gmail e oferecendo uma visão consolidada de arquivos.

## 📍 Estado Atual
**Fundação do monorepo, backend e frontend mínimos inicializados; base local de
identidade PostgreSQL/Supabase versionada.**
A visão do produto, requisitos funcionais, não-funcionais e a arquitetura de alto nível foram definidos e consolidados.

A migration de `public.profiles`, criação automática de perfil, RLS e
privilégios mínimos está implementada no repositório, mas ainda não foi
aplicada a um projeto Supabase remoto. A validação de banco permanece pendente
de um ambiente PostgreSQL/Supabase local.

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

⚠️ **Atenção**: A implementação das funcionalidades de negócio ainda não foi iniciada. O projeto encontra-se na etapa de fundação técnica.

## 🗓️ Próximos Passos
1. Planejamento técnico detalhado (Design de API e Banco de Dados).
2. Implementação da fundação do monorepo (Concluído).
3. Inicialização do backend mínimo (Concluído).
4. Aplicação e validação local da migration de perfis; implementação futura do
   fluxo de autenticação.
5. Integração com a Gmail API.
6. Desenvolvimento do motor de busca e galeria de anexos.
7. Estratégia de testes e deploy.
