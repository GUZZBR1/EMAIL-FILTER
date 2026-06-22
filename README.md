# Email Filter

## 🎯 Objetivo Geral
O Email Filter é uma aplicação web projetada para conectar múltiplas contas do Gmail e facilitar a localização de e-mails e anexos por meio de um sistema de filtros visuais avançados, eliminando a necessidade de dominar a sintaxe de busca do Gmail e oferecendo uma visão consolidada de arquivos.

## 📍 Estado Atual
**Fase de Planejamento e Especificação**.
A visão do produto, requisitos funcionais, não-funcionais e a arquitetura de alto nível foram definidos e consolidados.

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

---

⚠️ **Atenção**: O desenvolvimento do código da aplicação ainda não foi iniciado. O projeto encontra-se rigorosamente na etapa de design e especificação.

## 🗓️ Próximos Passos
1. Planejamento técnico detalhado (Design de API e Banco de Dados).
2. Estruturação da fundação do monorepo.
3. Implementação do fluxo de autenticação e perfis.
4. Integração com a Gmail API.
5. Desenvolvimento do motor de busca e galeria de anexos.
6. Estratégia de testes e deploy.
