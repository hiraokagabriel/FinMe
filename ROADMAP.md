\# Roadmap – FinMe



Este arquivo dá uma visão geral da direção do FinMe e das próximas etapas de desenvolvimento.  

O roadmap é organizado em marcos (M1, M2, …), cada um com um foco específico.



> Este roadmap é um documento vivo e será atualizado conforme novas funcionalidades forem desenvolvidas e prioridades mudarem.



\---



\## Visão geral



FinMe é um app de finanças para pessoas que lidam com \*\*alto volume de cartões, contas e bancos\*\*, com foco em:



\- Provisionamento de gastos futuros.

\- Visão consolidada de gastos passados, recentes e próximos.

\- Organização de dezenas de cartões (10, 20, 30+), inclusive múltiplos cartões do mesmo banco.

\- Dois modos de uso: \*\*Modo Simples\*\* (iniciante) e \*\*Modo Ultra\*\* (usuário avançado).



\---



\## Estado atual



\- Status: \*\*Em construção\*\* (MVP em desenvolvimento).

\- Plataforma principal atual: \*\*Windows (desktop)\*\*.

\- Público alvo inicial: usuário final avançado (quem trabalha com muitos cartões), mas com espaço para iniciantes via Modo Simples.



\---



\## M1 – Infraestrutura básica \& setup de desenvolvimento



\*\*Objetivo:\*\* Ter um projeto Flutter estruturado, rodando em desktop, com base para evolução.



\*\*Itens previstos:\*\*



\- Projeto Flutter criado e versionado no GitHub.

\- Configuração básica de:

&#x20; - Pastas (`lib/`, `core/`, `features/`, etc.).

&#x20; - Assets e temas iniciais.

\- Tela inicial simples com:

&#x20; - Placeholder para dashboard financeiro futuro.

&#x20; - Navegação mínima entre telas.



\*\*Não incluso em M1:\*\*



\- Regras complexas de domínio financeiro.

\- Persistência definitiva (pode ser em memória ou mock inicial).



\---



\## M2 – Núcleo financeiro (MVP funcional)



\*\*Objetivo:\*\* Permitir uso básico do FinMe para controle de cartões, receitas e despesas.



\*\*Funcionalidades planejadas:\*\*



\- \*\*Cadastro de cartões\*\*

&#x20; - Múltiplos cartões por banco.

&#x20; - Dados mínimos: nome do cartão, banco, tipo (crédito/débito), dia de vencimento, limite opcional.



\- \*\*Cadastro de receitas e despesas\*\*

&#x20; - Registro de transações com:

&#x20;   - Valor, data, tipo (receita/despesa).

&#x20;   - Forma de pagamento (crédito, débito, boleto, pix, etc.).

&#x20;   - Associação a um cartão/conta quando aplicável.

&#x20; - Registro de boletos:

&#x20;   - Pagos na hora.

&#x20;   - Provisionados para data futura.



\- \*\*Categorias de despesas\*\*

&#x20; - CRUD básico de categorias.

&#x20; - Associação de transações a categorias.



\- \*\*Visualização básica\*\*

&#x20; - Lista filtrável por período (mês, semana, datas customizadas).

&#x20; - Total de gastos por categoria em um período.



\*\*Não incluso em M2:\*\*



\- Modo Ultra completo (apenas estrutura inicial).

\- Visualizações avançadas (gráficos complexos, dashboards detalhados).



\---



\## M3 – Modo Simples vs Modo Ultra



\*\*Objetivo:\*\* Entregar experiências distintas de uso, respeitando o nível de complexidade desejado.



\*\*Funcionalidades planejadas:\*\*



\- \*\*Modo Simples\*\*

&#x20; - Configuração via toggle ou ajuste nas preferências do app.

&#x20; - Interface reduzida com foco em:

&#x20;   - Dinheiro que sai da conta.

&#x20;   - Valor de faturas principais.

&#x20;   - Menos campos/menos telas.



\- \*\*Modo Ultra\*\*

&#x20; - Interface com maior densidade de informações:

&#x20;   - Vários cartões por banco e entre bancos.

&#x20;   - Visão de gastos por cartão, por banco e consolidado.

&#x20;   - Provisionamento de gastos futuros (parcelas, boletos vencendo).

&#x20; - Configuração de colunas e filtros avançados.



\- \*\*Persistência das preferências\*\*

&#x20; - Lembrar qual modo o usuário utilizou por último.

&#x20; - Persistir configurações básicas de visualização.



\*\*Não incluso em M3:\*\*



\- Recomendações automáticas ou IA.

\- Integrações com bancos ou APIs externas.



\---



\## M4 – Detecção de gastos desnecessários \& análises



\*\*Objetivo:\*\* Ajudar o usuário a identificar desperdícios e oportunidades de economia.



\*\*Funcionalidades planejadas:\*\*



\- Identificação de:

&#x20; - Assinaturas recorrentes (streamings, serviços, etc.).

&#x20; - Anuidades e tarifas de cartões.

\- Relatórios como:

&#x20; - “Gastos recorrentes deste mês” vs meses anteriores.

&#x20; - “Top categorias onde você mais gastou neste período”.

\- Visão de volume de gastos no \*\*débito\*\*:

&#x20; - Para onde está indo o dinheiro do dia a dia.

&#x20; - Sumarização por categoria e por estabelecimento (quando houver).



\*\*Não incluso em M4:\*\*



\- Conexão automática com extratos bancários (tudo manual/importado pelo usuário por enquanto).

\- Machine learning avançado.



\---



\## M5 – UX, visualizações e distribuição



\*\*Objetivo:\*\* Melhorar a experiência de uso e facilitar a adoção.



\*\*Funcionalidades planejadas:\*\*



\- Refinamento UX/UI:

&#x20; - Melhorias em layout, ícones, cores, responsividade.

&#x20; - Ajustes específicos para Modo Simples vs Modo Ultra.



\- Visualizações gráficas:

&#x20; - Gráficos simples de categorias.

&#x20; - Linha de tempo de gastos (por dia/semana/mês).



\- Distribuição:

&#x20; - Empacotar e distribuir um \*\*.exe para Windows\*\*.

&#x20; - Preparar base para builds Android (APK/AAB para testes).



\*\*Não incluso em M5:\*\*



\- Publicação em lojas (Microsoft Store, Google Play, App Store) – a definir.



\---



\## Futuro (ideias sem compromisso de prazo)



\- Importação/exportação de dados (CSV, backup).

\- Suporte completo a:

&#x20; - iOS / iPadOS.

&#x20; - macOS.

\- Painel “Saúde financeira” com indicadores e dicas.

\- Possíveis integrações com bancos, APIs de extrato ou agregadores financeiros.

\- Modo “auditoria rápida” para revisar um período (ex.: últimos 15 dias) e marcar gastos como essenciais/supérfluos.

