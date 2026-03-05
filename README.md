# 📅 dimCalendario — Tabela Calendário para SQL Server

## 📌 Visão Geral

Este repositório contém um conjunto de scripts T-SQL para criação de uma **tabela de dimensão calendário** (`dimCalendario`) em um banco de dados SQL Server. A solução é voltada para equipes de Engenharia de Dados que utilizam arquiteturas Data Warehouse (DW) e precisam de uma dimensão temporal robusta, multilíngue e totalmente configurável para uso em pipelines ETL, relatórios e análises de BI.

A tabela gerada expõe mais de **100 atributos temporais** organizados em grupos semânticos (dia, semana, mês, trimestre, semestre, bimestre, quinzena, ano fiscal, feriados, estações do ano, etc.), todos calculados de forma dinâmica a partir de um intervalo de datas configurável.

---

## 🗂️ Estrutura dos Scripts

Os scripts devem ser executados **estritamente na ordem numérica indicada pelo prefixo do arquivo**, pois há dependências entre eles:

```
01_CriarFuncoesCalendario.sql       ← Funções auxiliares (base para tudo)
02_CriarTabelaTraducaoColunas.sql   ← Tabela e função de tradução de colunas
03_CriarTabelasFeriados.sql         ← Tabelas de feriados fixos e móveis
04_CriarTabelaCalendario.sql        ← Tabela calendário final (produto principal)
```

---

## 🔧 Pré-requisitos

- **SQL Server 2016+** (requer suporte a `FORMAT()`, `DATEFROMPARTS()`, `EOMONTH()` e `sp_executesql`)
- Permissão para criar **schemas**, **tabelas**, **funções** e **índices** no banco de dados de destino
- Execução sequencial dos scripts no mesmo banco de dados

---

## 📄 Detalhamento dos Scripts

### `01_CriarFuncoesCalendario.sql`

Cria todas as **funções T-SQL auxiliares** utilizadas pelos scripts subsequentes. Este é o alicerce da solução — nenhum outro script funciona sem ele.

| Função | Tipo | Descrição |
|---|---|---|
| `dbo.fn_CalcularPascoa` | Scalar | Implementa o **Algoritmo de Gauss/Butcher** para calcular a data da Páscoa a partir de um ano inteiro. Fundamental para o cálculo de feriados móveis (Carnaval, Sexta-Feira Santa, Corpus Christi). |
| `dbo.fn_CalcularSemanaISO` | Inline TVF | Calcula o **número da semana conforme a norma ISO 8601**, incluindo tratamento correto de semanas que cruzam a virada do ano (casos em que a semana 1 pode pertencer ao ano anterior ou posterior). Retorna também as datas de início e fim da semana ISO e o `AnoISO`. |
| `dbo.fn_IsDiaUtil` | Scalar | Retorna `BIT` indicando se uma data é dia útil, considerando fim de semana (sábado/domingo) e o flag de feriado recebido como parâmetro. |
| `dbo.fn_ObterTextoLocalizado` | Scalar | Dicionário interno de textos multilíngues. Recebe uma chave textual (ex: `'TextoAtual'`, `'PrefixoTrimestre'`, `'TextoVerao'`) e um `CultureInfo` (`pt-BR`, `en-US`, `es-ES`) e retorna o texto correspondente no idioma correto. Permite que toda a tabela seja gerada em diferentes idiomas sem alterar a lógica principal. |
| `dbo.fn_CapitalizarTexto` | Scalar | Implementa **Title Case** em T-SQL puro (sem CLR). Percorre o texto caractere a caractere e capitaliza a primeira letra de cada palavra, respeitando espaços e hífens como separadores. |
| `dbo.fn_CalcularSemanaUtil` | Inline TVF | Calcula o início e o fim da **semana útil** a partir de uma data de referência, com os dias de início e fim da semana configuráveis via parâmetro (padrão: segunda a sexta). Suporta semanas que cruzam o final de semana e um flag `@UsarSemanaFutura` para projeção para a semana seguinte. |

---

### `02_CriarTabelaTraducaoColunas.sql`

Cria a tabela `DW.TraducaoColunas` e a função `DW.fn_ObterNomeTraduzido`, que formam a camada de **internacionalização dos metadados** da solução.

**Tabela `DW.TraducaoColunas`**

Armazena o mapeamento de nomes de colunas entre idiomas. A chave primária composta garante unicidade por par origem-destino.

```sql
CREATE TABLE DW.TraducaoColunas (
    IdiomaOrigem   NVARCHAR(10),   -- Ex: 'pt-BR'
    NomeOriginal   NVARCHAR(128),  -- Ex: 'TrimestreNumero'
    IdiomaDestino  NVARCHAR(10),   -- Ex: 'en-US'
    NomeTraduzido  NVARCHAR(128),  -- Ex: 'QuarterNumber'
    PRIMARY KEY (IdiomaOrigem, NomeOriginal, IdiomaDestino)
)
```

O script popula a tabela com traduções de **`pt-BR` → `en-US`** e **`pt-BR` → `es-ES`** para todos os ~100 atributos da tabela calendário, cobrindo os grupos: Data, Ano, Dia, Mês, Trimestre, Semana, Semana Útil, Semestre, Bimestre, Quinzena, Fechamento, Estação, Feriados/Dias Úteis, Ano Fiscal, Mês Fiscal e Trimestre Fiscal.

**Função `DW.fn_ObterNomeTraduzido`**

Função scalar que consulta a tabela e retorna o nome traduzido de uma coluna. Se não houver tradução registrada, retorna o nome original como fallback — garantindo comportamento seguro mesmo com traduções incompletas.

> ⚠️ **Nota:** A renomeação física das colunas na tabela final é uma funcionalidade opcional e está implementada como bloco comentado no script `04`. Ela pode ser ativada quando o consumidor final da tabela (ex: uma ferramenta de BI) exige os nomes das colunas no idioma de destino.

---

### `03_CriarTabelasFeriados.sql`

Responsável pela criação e população das **tabelas de feriados**, separando a lógica em feriados fixos e móveis para facilitar manutenção e extensibilidade.

#### Tabelas criadas

**`DW.dimFeriadosFixos`** — Repositório de feriados com data fixa (mesmo dia e mês todo ano), segmentados por `CultureInfo`:

| Culture | Feriados incluídos |
|---|---|
| `pt-BR` | Confraternização Universal, Aniversário da Cidade (SP), Tiradentes, Dia do Trabalhador, Revolução Constitucionalista, Independência, N. Srª Aparecida, Finados, Proclamação da República, Consciência Negra, Véspera de Natal, Natal, Véspera de Ano Novo |
| `en-US` | New Year's Day, MLK Day, Presidents' Day, Memorial Day, Independence Day, Labor Day, Columbus Day, Veterans Day, Thanksgiving, Christmas Eve, Christmas Day, New Year's Eve |
| `es-ES` | Año Nuevo, Día de Reyes, Día del Trabajo, Asunción, Fiesta Nacional, Todos los Santos, Constitución, Inmaculada, Nochebuena, Navidad, Nochevieja |

**`DW.dimFeriadosMoveis`** — Repositório de feriados calculados em relação à data da Páscoa, usando offset em dias (`DiasRelativosPascoa`):

| Culture | Feriado | Offset |
|---|---|---|
| `pt-BR` | Carnaval | -47 dias |
| `pt-BR` | Sexta-Feira Santa | -2 dias |
| `pt-BR` | Páscoa | 0 dias |
| `pt-BR` | Corpus Christi | +60 dias |
| `en-US` | Good Friday | -2 dias |
| `en-US` | Easter Sunday | 0 dias |
| `es-ES` | Viernes Santo | -2 dias |
| `es-ES` | Corpus Christi | +60 dias |

**`DW.dimFeriados`** — Tabela processada e final. Combina feriados fixos e móveis, calculando as datas absolutas para cada ano no intervalo configurado (`@DataInicial` a `@DataFinal`, padrão: 2000–2050). Trata **colisões de feriados** (quando dois feriados caem na mesma data) por meio de concatenação dos nomes com `/` como separador, mantendo sempre apenas um registro por `(Data, CultureInfo)`.

#### Fluxo de processamento

```
dimFeriadosFixos  ──┐
                    ├── CROSS JOIN com anos do intervalo ──► dimFeriados
dimFeriadosMoveis  ─┘  (via fn_CalcularPascoa por ano)      (com dedup)
```

O parâmetro `@RemoverTabelasAuxiliares` controla se as tabelas `dimFeriadosFixos` e `dimFeriadosMoveis` são mantidas ou descartadas ao final da execução, permitindo que o ambiente fique enxuto em produção.

---

### `04_CriarTabelaCalendario.sql`

Script principal. Gera a **tabela de dimensão calendário** com todos os seus atributos, a partir das funções e tabelas criadas nos scripts anteriores.

#### Parâmetros de configuração

Todos os parâmetros são declarados no início do script, facilitando reutilização e automação:

| Parâmetro | Padrão | Descrição |
|---|---|---|
| `@SchemaTabela` | `'DW'` | Schema de destino |
| `@NomeTabelaCalendario` | `'dimCalendario'` | Nome da tabela gerada |
| `@CultureInfo` | `'en-US'` | Idioma dos textos da tabela (nomes de meses, dias, prefixos) |
| `@CultureInfoFeriados` | `'pt-BR'` | Idioma dos feriados (pode ser independente do idioma principal) |
| `@UsarTabelaFato` | `1` | Define o intervalo de datas automaticamente a partir da tabela fato |
| `@NomeTabelaFato` | `'DW.fatVendas'` | Tabela fato de referência para datas mínima/máxima |
| `@ColunaTabelaFato` | `'Data'` | Coluna de data na tabela fato |
| `@AnosAntes` | `0` | Extensão do intervalo antes da data mínima da fato |
| `@AnosDepois` | `25` | Extensão do intervalo após a data máxima da fato |
| `@DataInicialFixa` | `'2020-01-01'` | Data inicial quando não usar tabela fato |
| `@MesFimAnoFiscal` | `12` | Define o encerramento do ano fiscal (12 = calendário padrão) |
| `@DiaInicioMesFechamento` | `1` | Dia de corte para definição do mês de fechamento |
| `@ManterTabelaFeriados` | `0` | Mantém ou descarta `dimFeriados` após o processamento |

#### Determinação dinâmica do intervalo de datas

O script implementa uma lógica resiliente para definir o intervalo de datas da tabela:

```
@UsarTabelaFato = 1 E tabela fato existe?
    ├── SIM → MIN/MAX da coluna de data da fato ± anos de margem
    │         (fallback para datas fixas se a tabela estiver vazia)
    └── NÃO → Usa @DataInicialFixa e @DataFinalFixa
```

Isso permite que a tabela calendário se ajuste automaticamente ao crescimento dos dados históricos da fato, sem necessidade de manutenção manual das datas.

#### Geração da série de datas

Utiliza uma **CTE recursiva** para gerar a sequência diária, com `OPTION (MAXRECURSION 32767)` para suportar intervalos de até ~89 anos:

```sql
WITH CTE_Datas AS (
    SELECT @DataInicial AS Data
    UNION ALL
    SELECT DATEADD(DAY, 1, Data)
    FROM CTE_Datas
    WHERE DATEADD(DAY, 1, Data) <= @DataFinal
)
SELECT Data INTO #Datas FROM CTE_Datas
OPTION (MAXRECURSION 32767);
```

#### Atributos da tabela calendário

A tabela gerada contém os seguintes grupos de atributos:

**📌 Data base**
`Data` (PK), `DataIndice`, `DiasParaHoje`, `DataAtual`

**📅 Ano**
`Ano`, `AnoInicio`, `AnoFim`, `AnoIndice`, `AnoDecrescenteNome`, `AnoDecrescenteNumero`, `AnosParaHoje`, `AnoAtual`

**📆 Dia**
`DiaDoMes`, `DiaDoAno`, `DiaDaSemanaNumero`, `DiaDaSemanaNome`, `DiaDaSemanaNomeAbreviado`, `DiaDaSemanaNomeIniciais`

**🗓️ Mês**
`MesNumero`, `MesNome`, `MesNomeAbreviado`, `MesNomeIniciais`, `MesAnoNome`, `MesAnoNumero`, `MesDiaNumero`, `MesDiaNome`, `MesInicio`, `MesFim`, `MesIndice`, `MesesParaHoje`, `MesAtualNome`, `MesAtualNomeAbreviado`, `MesAnoAtualNome`

**📊 Trimestre**
`TrimestreNumero`, `TrimestreNome`, `TrimestreAnoNome`, `TrimestreAnoNumero`, `TrimestreInicio`, `TrimestreFim`, `TrimestreIndice`, `TrimestresParaHoje`, `TrimestreAtual`, `TrimestreAnoAtual`, `MesDoTrimestreNumero`

**🗒️ Semana ISO (ISO 8601)**
`SemanaDoAnoNumeroISO`, `AnoISO`, `SemanaAnoNumeroISO`, `SemanaAnoNomeISO`, `SemanaInicioISO`, `SemanaFimISO`, `SemanaIndiceISO`, `SemanasParaHojeISO`, `SemanaAtualISO`, `SemanaPeriodoNome`, `SemanaDoMesNumero`

**📈 Semestre, Bimestre e Quinzena**
Grupos completos com número, nome, índice, distância relativa ao período atual e flag de "atual" para cada granularidade.

**📉 Fechamento**
`DataDeFechamentoRef`, `AnoFechamento`, `MesFechamentoNome`, `MesFechamentoNomeAbreviado`, `MesFechamentoNumero`, `MesAnoFechamentoNome`, `MesAnoFechamentoNumero`
> Suporta ciclos de fechamento configuráveis via `@DiaInicioMesFechamento`.

**🌤️ Estações do Ano**
Atributos separados para **hemisfério norte** (`EstacaoNorteNumero`, `EstacaoNorteNome`) e **hemisfério sul** (`EstacaoSulNumero`, `EstacaoSulNome`), calculados com base no dia do ano e traduzidos conforme o `CultureInfo`.

**🏖️ Feriados e Dias Úteis**
`Feriado` (nome do feriado ou `NULL`), `DiaUtilNumero` (BIT), `DiaUtilNome`
> A lógica de dia útil considera fins de semana e feriados simultaneamente.

**💼 Ano Fiscal**
`AnoFiscalInicialNumero`, `AnoFiscalFinalNumero`, `AnoFiscal`, `AnoFiscalInicio`, `AnoFiscalFim`, `AnoFiscalAtual`, `AnosFiscaisParaHoje`

**💼 Mês Fiscal**
`MesFiscalNumero`, `MesFiscalNome`, `MesFiscalNomeAbreviado`, `MesFiscalAtual`, `MesAnoFiscalNome`, `MesAnoFiscalNumero`, `MesAnoFiscalAtual`, `MesesFiscaisParaHoje`

**💼 Trimestre Fiscal**
`TrimestreFiscalNumero`, `TrimestreFiscalNome`, `MesDoTrimestreFiscalNumero`, `AnoTrimestreFiscalNome`, `AnoTrimestreFiscalNumero`, `TrimestreFiscalInicio`, `TrimestreFiscalFim`, `TrimestresFiscaisParaHoje`, `TrimestreFiscalAtual`, `DiaDoTrimestreFiscal`

#### Índices criados automaticamente

Ao final da geração, o script cria índices não clusterizados para as colunas de filtro mais comuns em cargas ETL e consultas analíticas:

```sql
IX_{schema}_{tabela}_Ano           ON (Ano)
IX_{schema}_{tabela}_MesAno        ON (Ano, MesNumero)
IX_{schema}_{tabela}_TrimestreAno  ON (Ano, TrimestreNumero)
IX_{schema}_{tabela}_DiaUtil       ON (DiaUtilNumero)
IX_{schema}_{tabela}_AnoFiscal     ON (AnoFiscalInicialNumero)
```

---

## 🌍 Suporte a Idiomas (CultureInfo)

Toda a solução foi projetada com **internacionalização nativa**. Os textos, nomes de meses, dias da semana, prefixos de períodos e nomes de feriados são gerados dinamicamente com base no parâmetro `@CultureInfo`, utilizando a função `FORMAT()` do SQL Server e o dicionário da `fn_ObterTextoLocalizado`.

| CultureInfo | Idioma |
|---|---|
| `pt-BR` | Português (Brasil) |
| `en-US` | Inglês (Estados Unidos) |
| `es-ES` | Espanhol (Espanha) |

> 💡 É possível ter o idioma principal da tabela diferente do idioma dos feriados. Exemplo: tabela em `en-US` com feriados brasileiros (`pt-BR`).

---

## 🚀 Como Usar

### 1. Clone o repositório

```bash
git clone https://github.com/diegotimoteo/calendar-dimension.git
```

### 2. Execute os scripts em ordem no SQL Server Management Studio (SSMS) ou Azure Data Studio

```sql
-- Passo 1: Funções auxiliares
:r 01_CriarFuncoesCalendario.sql

-- Passo 2: Tabela e função de tradução de colunas
:r 02_CriarTabelaTraducaoColunas.sql

-- Passo 3: Tabelas de feriados
:r 03_CriarTabelasFeriados.sql

-- Passo 4: Tabela calendário final
:r 04_CriarTabelaCalendario.sql
```

### 3. Configure os parâmetros antes da execução

Edite a **seção de parâmetros de configuração** no início de cada script conforme o seu ambiente. Os parâmetros mais relevantes estão em `04_CriarTabelaCalendario.sql`:

```sql
DECLARE @SchemaTabela           NVARCHAR(128) = 'DW';
DECLARE @NomeTabelaCalendario   NVARCHAR(128) = 'dimCalendario';
DECLARE @CultureInfo            NVARCHAR(10)  = 'pt-BR';
DECLARE @CultureInfoFeriados    NVARCHAR(10)  = 'pt-BR';
DECLARE @MesFimAnoFiscal        INT           = 12;
DECLARE @UsarTabelaFato         BIT           = 0;
DECLARE @DataInicialFixa        DATE          = '2020-01-01';
```

### 4. Consulte a tabela gerada

```sql
-- Visão geral da tabela
SELECT TOP 100 * FROM DW.dimCalendario ORDER BY Data;

-- Apenas dias úteis do mês atual
SELECT * FROM DW.dimCalendario
WHERE MesesParaHoje = 0
  AND DiaUtilNumero = 1;

-- Feriados do ano corrente
SELECT Data, Feriado
FROM DW.dimCalendario
WHERE AnosParaHoje = 0
  AND Feriado IS NOT NULL
ORDER BY Data;

-- Resumo de dias úteis por mês do ano atual
SELECT MesAnoNome, COUNT(*) AS TotalDias,
       SUM(CAST(DiaUtilNumero AS INT)) AS DiasUteis
FROM DW.dimCalendario
WHERE AnosParaHoje = 0
GROUP BY MesAnoNome, MesIndice
ORDER BY MesIndice;
```

---

## 🏗️ Diagrama de Dependências

```
01_CriarFuncoesCalendario.sql
        │
        ▼
02_CriarTabelaTraducaoColunas.sql
        │
        ▼
03_CriarTabelasFeriados.sql
   (usa fn_CalcularPascoa do script 01)
        │
        ▼
04_CriarTabelaCalendario.sql
   (usa todas as funções do script 01,
    a tabela dimFeriados do script 03,
    e opcionalmente a TraducaoColunas do script 02)
```

---

## 📐 Decisões de Design

- **Tabela física em vez de view:** A tabela é materializada para garantir performance máxima em joins com tabelas fato de alto volume, sem reprocessamento em cada query.
- **SQL dinâmico (sp_executesql):** Usado para permitir nomes de schema e tabela configuráveis sem exigir alteração do corpo dos scripts.
- **Separação feriados fixos / móveis:** Facilita manutenção futura — adicionar um novo feriado fixo é um simples `INSERT`; feriados móveis só precisam do offset relativo à Páscoa.
- **Zero hardcode de datas:** O intervalo é derivado da tabela fato em tempo de execução, evitando problemas de manutenção ao longo do tempo.
- **Caractere zero-width space (ZWS) para ordenação:** Colunas de iniciais (`DiaDaSemanaNomeIniciais`, `MesNomeIniciais`) usam `NCHAR(8203)` repetido como prefixo para forçar ordenação cronológica natural em ferramentas de BI que ordenam por valor texto.

---

## 🙏 Créditos

**Autor e mantenedor:** [Diego Timóteo](https://github.com/diegotimoteo)

Este projeto foi inspirado pelo trabalho de **[Alison Pezzott](https://github.com/alisonpezzott/tmdl-calendario/)**, autor do projeto original `tmdl-calendario` — uma tabela calendário modelada em TMDL para uso direto no Power BI / Analysis Services. A ideia de estrutura, os grupos de atributos e a abordagem multilíngue foram adaptados e estendidos para o ambiente SQL Server nativo.

---

## 📝 Licença

MIT License

Copyright (c) 2025 Diego Timóteo

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
