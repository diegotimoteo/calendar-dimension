--========================================================================================================================================
-- Script para criar uma tabela calendário no SQL Server
-- Versão 1.0
-- Autor: Diego Timóteo
-- Requer a execução prévia dos scripts 01_CriarFuncoesCalendario.sql, 02_CriarTabelaTraducaoColunas.sql e 03_CriarTabelaFeriados.sql
--========================================================================================================================================


-- Configurações iniciais
SET NOCOUNT ON;
GO

-- =============================================
-- SEÇÃO DE PARÂMETROS DE CONFIGURAÇÃO
-- =============================================

-- Parâmetros de nomenclatura e schemas
DECLARE @SchemaTabela NVARC
7HAR(128) = 'DW';           -- Schema onde a tabela será criada
DECLARE @NomeTabelaCalendario NVARCHAR(128) = 'dimCalendarioVendas'; -- Nome da tabela calendário que será criada
DECLARE @NomeTabelaCompleto NVARCHAR(257) = @SchemaTabela + '.' + @NomeTabelaCalendario; -- Nome completo da tabela
DECLARE @CultureInfo NVARCHAR(10) = 'en-US';         -- Idioma principal da tabela (para nomes de meses, dias, etc.)

-- Parâmetro para o nome da tabela de feriados
-- Parâmetros para internacionalização
-- Opções disponíveis para feriados:
-- 'pt-BR' = Feriados brasileiros
-- 'en-US' = Feriados dos Estados Unidos
-- 'es-ES' = Feriados da Espanha
-- 'custom' = Utiliza tabela personalizada de feriados (requer configuração adicional)
-- Se não for especificado, utiliza o mesmo idioma da configuração principal

DECLARE @SchemaTabelaFeriados NVARCHAR(128) = 'DW';    -- Schema onde a tabela de feriados está localizada
DECLARE @NomeTabelaFeriados NVARCHAR(128) = 'dimFeriados'; -- Nome da tabela de feriados
DECLARE @NomeTabelaFeriadosCompleto NVARCHAR(257) = @SchemaTabelaFeriados + '.' + @NomeTabelaFeriados; -- Nome completo da tabela
DECLARE @CultureInfoFeriados NVARCHAR(10) = 'pt-BR'; -- Idioma específico para feriados (pode ser diferente do idioma principal)

-- Parâmetro para decidir se a tabela de feriados será mantida após o processamento
DECLARE @ManterTabelaFeriados BIT = 0; -- 1 = Manter, 0 = Excluir

-- Configuração para determinar o intervalo de datas
DECLARE @UsarTabelaFato BIT = 1;								  -- 1 = Usar tabela fato, 0 = Usar datas fixas
DECLARE @NomeTabelaFato NVARCHAR(128) = 'DW.fatVendas';           -- Nome da tabela fato
DECLARE @ColunaTabelaFato NVARCHAR(128) = 'Data';				  -- Nome da coluna de data na tabela fato
DECLARE @AnosAntes INT = 0;										  -- Anos antes da data mínima (para comparações)
DECLARE @AnosDepois INT = 25;									  -- Anos depois da data máxima (para projeções)

-- Para uso quando @UsarTabelaFato = 0:
DECLARE @DataInicialFixa DATE = '2020-01-01'; 
DECLARE @DataFinalFixa DATE = DATEFROMPARTS(YEAR(GETDATE()) + @AnosDepois, 12, 31);

-- Parâmetros adicionais
DECLARE @MesFimAnoFiscal INT = 12;                  -- Mês de fim do ano fiscal
DECLARE @DiaInicioMesFechamento INT = 1;            -- Dia de início do mês de fechamento

-- Variáveis auxiliares que serão calculadas
DECLARE @DataInicial DATE;
DECLARE @DataFinal DATE;
DECLARE @SQL NVARCHAR(MAX);
DECLARE @DataAtual DATE = CAST(GETDATE() AS DATE);
DECLARE @AnoAtual INT = YEAR(@DataAtual);
DECLARE @MesAtual INT = MONTH(@DataAtual);
DECLARE @AnoFiscalAtual INT = YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, @DataAtual));
DECLARE @ZWS NVARCHAR(1) = NCHAR(8203);  -- Carácter invisível para ordenação

-- =============================================
-- FIM DE PARÂMETROS DE CONFIGURAÇÃO
-- =============================================

-- Obter textos localizados
DECLARE @TextoAtual NVARCHAR(20) = dbo.fn_ObterTextoLocalizado('TextoAtual', @CultureInfo);
DECLARE @PrefixoTrimestre NVARCHAR(2) = dbo.fn_ObterTextoLocalizado('PrefixoTrimestre', @CultureInfo);
DECLARE @PrefixoSemana NVARCHAR(2) = dbo.fn_ObterTextoLocalizado('PrefixoSemana', @CultureInfo);
DECLARE @PrefixoSemestre NVARCHAR(2) = dbo.fn_ObterTextoLocalizado('PrefixoSemestre', @CultureInfo);
DECLARE @PrefixoBimestre NVARCHAR(2) = dbo.fn_ObterTextoLocalizado('PrefixoBimestre', @CultureInfo);
DECLARE @PrefixoQuinzena NVARCHAR(2) = dbo.fn_ObterTextoLocalizado('PrefixoQuinzena', @CultureInfo);
DECLARE @TextoVerao NVARCHAR(20) = dbo.fn_CapitalizarTexto(dbo.fn_ObterTextoLocalizado('TextoVerao', @CultureInfo));
DECLARE @TextoPrimavera NVARCHAR(20) = dbo.fn_CapitalizarTexto(dbo.fn_ObterTextoLocalizado('TextoPrimavera', @CultureInfo));
DECLARE @TextoOutono NVARCHAR(20) = dbo.fn_CapitalizarTexto(dbo.fn_ObterTextoLocalizado('TextoOutono', @CultureInfo));
DECLARE @TextoInverno NVARCHAR(20) = dbo.fn_CapitalizarTexto(dbo.fn_ObterTextoLocalizado('TextoInverno', @CultureInfo));
DECLARE @TextoDiaUtil NVARCHAR(30) = dbo.fn_CapitalizarTexto(dbo.fn_ObterTextoLocalizado('TextoDiaUtil', @CultureInfo));
DECLARE @TextoDiaNaoUtil NVARCHAR(30) = dbo.fn_CapitalizarTexto(dbo.fn_ObterTextoLocalizado('TextoDiaNaoUtil', @CultureInfo));
DECLARE @PrefixoAnoFiscal NVARCHAR(30) = dbo.fn_ObterTextoLocalizado('PrefixoAnoFiscal', @CultureInfo);
DECLARE @PrefixoTrimestreFiscal NVARCHAR(30) = dbo.fn_ObterTextoLocalizado('PrefixoTrimestreFiscal', @CultureInfo);

-- Verificar se a tabela de feriados existe (usando a variável @NomeTabelaFeriadosCompleto)
DECLARE @TabelaFeriadosExists BIT = 0;
SET @SQL = N'
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = ''' + @NomeTabelaFeriados + ''' AND schema_id = SCHEMA_ID(''' + @SchemaTabelaFeriados + '''))
    SET @TabelaFeriadosExists = 1';
EXEC sp_executesql @SQL, N'@TabelaFeriadosExists BIT OUTPUT', @TabelaFeriadosExists OUTPUT;

IF @TabelaFeriadosExists = 0
BEGIN
    RAISERROR('A tabela %s não foi encontrada. Execute o script 03_CriarTabelaFeriados.sql primeiro.', 16, 1, @NomeTabelaFeriadosCompleto);
    RETURN;
END

-- Configuração para determinar o intervalo de datas
IF @UsarTabelaFato = 1 AND EXISTS (SELECT 1 FROM sys.objects WHERE name = PARSENAME(@NomeTabelaFato, 1) AND SCHEMA_NAME(schema_id) = PARSENAME(@NomeTabelaFato, 2))
BEGIN
    -- Consulta dinâmica para obter as datas da tabela fato
    SET @SQL = N'
        SELECT 
            @DataInicialOUT = DATEFROMPARTS(YEAR(MIN(' + QUOTENAME(@ColunaTabelaFato) + ')) - @AnosAntes, 1, 1),
            @DataFinalOUT = DATEFROMPARTS(YEAR(MAX(' + QUOTENAME(@ColunaTabelaFato) + ')) + @AnosDepois, 12, 31)
        FROM ' + @NomeTabelaFato + '
        WHERE ' + QUOTENAME(@ColunaTabelaFato) + ' IS NOT NULL';
        
    -- Executar a consulta dinâmica
    DECLARE @DataInicialOUT DATE;
    DECLARE @DataFinalOUT DATE;
    
    EXEC sp_executesql @SQL, 
        N'@AnosAntes INT, @AnosDepois INT, @DataInicialOUT DATE OUTPUT, @DataFinalOUT DATE OUTPUT', 
        @AnosAntes, @AnosDepois, @DataInicialOUT OUTPUT, @DataFinalOUT OUTPUT;
    
    SET @DataInicial = @DataInicialOUT;
    SET @DataFinal = @DataFinalOUT;
    
    -- Se a tabela estiver vazia ou a consulta falhar, use datas fixas
    IF @DataInicial IS NULL OR @DataFinal IS NULL
    BEGIN
        SET @DataInicial = @DataInicialFixa;
        SET @DataFinal = @DataFinalFixa;
        PRINT 'AVISO: Não foi possível obter datas da tabela fato. Usando datas fixas.';
    END
    ELSE
    BEGIN
        PRINT 'Usando datas da tabela fato: ' + CONVERT(VARCHAR, @DataInicial, 103) + ' até ' + CONVERT(VARCHAR, @DataFinal, 103);
    END
END
ELSE
BEGIN
    SET @DataInicial = @DataInicialFixa;
    SET @DataFinal = @DataFinalFixa;
    
    IF @UsarTabelaFato = 1
    BEGIN
        PRINT 'AVISO: Tabela fato especificada não existe. Usando datas fixas.';
    END
    ELSE
    BEGIN
        PRINT 'Usando datas fixas: ' + CONVERT(VARCHAR, @DataInicial, 103) + ' até ' + CONVERT(VARCHAR, @DataFinal, 103);
    END
END

-- Criar tabela temporária com todas as datas
IF OBJECT_ID('tempdb..#Datas') IS NOT NULL
    DROP TABLE #Datas;

-- Gera série de datas utilizando CTE recursiva
WITH CTE_Datas AS (
    SELECT @DataInicial AS Data
    UNION ALL
    SELECT DATEADD(DAY, 1, Data)
    FROM CTE_Datas
    WHERE DATEADD(DAY, 1, Data) <= @DataFinal
)
SELECT Data INTO #Datas FROM CTE_Datas
OPTION (MAXRECURSION 32767);

-- Criar e popular a tabela calendário final
SET @SQL = N'
IF OBJECT_ID(''' + @NomeTabelaCompleto + ''') IS NOT NULL
    DROP TABLE ' + @NomeTabelaCompleto;

EXEC sp_executesql @SQL;

SET @SQL = N'
CREATE TABLE ' + @NomeTabelaCompleto + N' (
    -- Colunas de Dados
    Data DATE PRIMARY KEY,
    DataIndice INT NOT NULL,
    DiasParaHoje INT NOT NULL,
    DataAtual NVARCHAR(20) NOT NULL,
    
    -- Ano
    Ano INT NOT NULL,
    AnoInicio DATE NOT NULL,
    AnoFim DATE NOT NULL,
    AnoIndice INT NOT NULL,
    AnoDecrescenteNome INT NOT NULL,
    AnoDecrescenteNumero INT NOT NULL,
    AnosParaHoje INT NOT NULL,
    AnoAtual NVARCHAR(20) NOT NULL,
    
    -- Dia
    DiaDoMes INT NOT NULL,
    DiaDoAno INT NOT NULL,
    DiaDaSemanaNumero INT NOT NULL,
    DiaDaSemanaNome NVARCHAR(30) NOT NULL,
    DiaDaSemanaNomeAbreviado NVARCHAR(30) NOT NULL,
    DiaDaSemanaNomeIniciais NVARCHAR(30) NOT NULL,
    
    -- Mês
    MesNumero INT NOT NULL,
    MesNome NVARCHAR(30) NOT NULL,
    MesNomeAbreviado NVARCHAR(30) NOT NULL,
    MesNomeIniciais NVARCHAR(30) NOT NULL,
    MesAnoNome NVARCHAR(20) NOT NULL,
    MesAnoNumero INT NOT NULL,
    MesDiaNumero INT NOT NULL,
    MesDiaNome NVARCHAR(30) NOT NULL,
    MesInicio DATE NOT NULL,
    MesFim DATE NOT NULL,
    MesIndice INT NOT NULL,
    MesesParaHoje INT NOT NULL,
    MesAtualNome NVARCHAR(30) NOT NULL,
    MesAtualNomeAbreviado NVARCHAR(30) NOT NULL,
    MesAnoAtualNome NVARCHAR(20) NOT NULL,
    
    -- Trimestre
    TrimestreNumero INT NOT NULL,
    TrimestreNome NVARCHAR(30) NOT NULL,
    TrimestreAnoNome NVARCHAR(30) NOT NULL,
    TrimestreAnoNumero INT NOT NULL,
    TrimestreInicio DATE NOT NULL,
    TrimestreFim DATE NOT NULL,
    TrimestreIndice INT NOT NULL,
    TrimestresParaHoje INT NOT NULL,
    TrimestreAtual NVARCHAR(30) NOT NULL,
    TrimestreAnoAtual NVARCHAR(30) NOT NULL,
    MesDoTrimestreNumero INT NOT NULL,
    
    -- Semana
    SemanaDoAnoNumeroISO INT NOT NULL,
    AnoISO INT NOT NULL,
    SemanaAnoNumeroISO INT NOT NULL,
    SemanaAnoNomeISO NVARCHAR(30) NOT NULL,
    SemanaInicioISO DATE NOT NULL,
    SemanaFimISO DATE NOT NULL,
    SemanaIndiceISO INT NOT NULL,
    SemanasParaHojeISO INT NOT NULL,
    SemanaAtualISO NVARCHAR(30) NOT NULL,
    SemanaPeriodoNome NVARCHAR(100) NOT NULL,
    SemanaDoMesNumero INT NOT NULL,
    
    -- Semestre
    SemestreNumero INT NOT NULL,
    SemestreAnoNome NVARCHAR(30) NOT NULL,
    SemestreAnoNumero INT NOT NULL,
    SemestreIndice INT NOT NULL,
    SemestresParaHoje INT NOT NULL,
    SemestreAtual NVARCHAR(30) NOT NULL,
    
    -- Bimestre
    BimestreNumero INT NOT NULL,
    BimestreAnoNome NVARCHAR(30) NOT NULL,
    BimestreAnoNumero INT NOT NULL,
    BimestreIndice INT NOT NULL,
    BimestresParaHoje INT NOT NULL,
    BimestreAtual NVARCHAR(30) NOT NULL,
    
    -- Quinzena
    QuinzenaDoMesNumero INT NOT NULL,
    QuinzenaMesNumero INT NOT NULL,
    QuinzenaMesNome NVARCHAR(30) NOT NULL,
    QuinzenaMesAnoNumero INT NOT NULL,
    QuinzenaMesAnoNome NVARCHAR(50) NOT NULL,
    QuinzenaIndice INT NOT NULL,
    QuinzenasParaHoje INT NOT NULL,
    QuinzenaAtual NVARCHAR(30) NOT NULL,
    
    -- Fechamento
    DataDeFechamentoRef DATE NOT NULL,
    AnoFechamento INT NOT NULL,
    MesFechamentoNome NVARCHAR(30) NOT NULL,
    MesFechamentoNomeAbreviado NVARCHAR(30) NOT NULL,
    MesFechamentoNumero INT NOT NULL,
    MesAnoFechamentoNome NVARCHAR(20) NOT NULL,
    MesAnoFechamentoNumero INT NOT NULL,
    
    -- Estação
    EstacaoNorteNumero INT NOT NULL,
    EstacaoNorteNome NVARCHAR(30) NOT NULL,
    EstacaoSulNumero INT NOT NULL,
    EstacaoSulNome NVARCHAR(30) NOT NULL,
    
    -- Dias Úteis e Feriados
    Feriado NVARCHAR(200) NULL,
    DiaUtilNumero BIT NOT NULL,
    DiaUtilNome NVARCHAR(30) NOT NULL,
    
    -- Ano Fiscal
    AnoFiscalInicialNumero INT NOT NULL,
    AnoFiscalFinalNumero INT NOT NULL,
    AnoFiscal NVARCHAR(30) NOT NULL,
    AnoFiscalInicio DATE NOT NULL,
    AnoFiscalFim DATE NOT NULL,
    AnoFiscalAtual NVARCHAR(30) NOT NULL,
    AnosFiscaisParaHoje INT NOT NULL,
    
    -- Mês Fiscal
    MesFiscalNumero INT NOT NULL,
    MesFiscalNome NVARCHAR(30) NOT NULL,
    MesFiscalNomeAbreviado NVARCHAR(30) NOT NULL,
    MesFiscalAtual NVARCHAR(30) NOT NULL,
    MesAnoFiscalNome NVARCHAR(50) NOT NULL,
    MesAnoFiscalNumero INT NOT NULL,
    MesAnoFiscalAtual NVARCHAR(50) NOT NULL,
    MesesFiscaisParaHoje INT NOT NULL,
    
    -- Trimestre Fiscal
    TrimestreFiscalNumero INT NOT NULL,
    TrimestreFiscalNome NVARCHAR(50) NOT NULL,
    MesDoTrimestreFiscalNumero INT NOT NULL,
    AnoTrimestreFiscalNome NVARCHAR(50) NOT NULL,
    AnoTrimestreFiscalNumero INT NOT NULL,
    TrimestreFiscalInicio DATE NOT NULL,
    TrimestreFiscalFim DATE NOT NULL,
    TrimestresFiscaisParaHoje INT NOT NULL,
    TrimestreFiscalAtual NVARCHAR(50) NOT NULL,
    DiaDoTrimestreFiscal INT NOT NULL
)';

EXEC sp_executesql @SQL;

-- Inserir dados na tabela calendário
-- Modificado para usar o nome dinâmico da tabela de feriados (@NomeTabelaFeriadosCompleto)
-- Modificado para usar os prefixos localizados para ano fiscal e trimestre fiscal
SET @SQL = N'
INSERT INTO ' + @NomeTabelaCompleto + N'
SELECT 
    -- Colunas de Data
    d.Data,
    CONVERT(INT, CONVERT(VARCHAR(8), d.Data, 112)) AS DataIndice,
    DATEDIFF(DAY, @DataAtual, d.Data) AS DiasParaHoje,
    CASE WHEN d.Data = @DataAtual THEN @TextoAtual ELSE FORMAT(d.Data, ''d'', @CultureInfo) END AS DataAtual,
    
    -- Ano
    YEAR(d.Data) AS Ano,
    DATEFROMPARTS(YEAR(d.Data), 1, 1) AS AnoInicio,
    DATEFROMPARTS(YEAR(d.Data), 12, 31) AS AnoFim,
    YEAR(d.Data) - YEAR(@DataInicial) + 1 AS AnoIndice,
    YEAR(d.Data) AS AnoDecrescenteNome,
    YEAR(d.Data) * -1 AS AnoDecrescenteNumero,
    YEAR(d.Data) - @AnoAtual AS AnosParaHoje,
    CASE WHEN YEAR(d.Data) = @AnoAtual THEN @TextoAtual ELSE CAST(YEAR(d.Data) AS NVARCHAR(20)) END AS AnoAtual,
    
    -- Dia
    DAY(d.Data) AS DiaDoMes,
    DATEPART(DAYOFYEAR, d.Data) AS DiaDoAno,
    DATEPART(WEEKDAY, d.Data) AS DiaDaSemanaNumero,
    dbo.fn_CapitalizarTexto(FORMAT(d.Data, ''dddd'', @CultureInfo)) AS DiaDaSemanaNome,
    dbo.fn_CapitalizarTexto(FORMAT(d.Data, ''ddd'', @CultureInfo)) AS DiaDaSemanaNomeAbreviado,
    REPLICATE(@ZWS, 7 - DATEPART(WEEKDAY, d.Data)) + 
    UPPER(LEFT(FORMAT(d.Data, ''ddd'', @CultureInfo), 1)) AS DiaDaSemanaNomeIniciais,
    
    -- Mês
    MONTH(d.Data) AS MesNumero,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMMM'', @CultureInfo)) AS MesNome,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) AS MesNomeAbreviado,
    REPLICATE(@ZWS, 12 - MONTH(d.Data)) + 
    UPPER(LEFT(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo), 1)) AS MesNomeIniciais,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) + ''/'' + RIGHT(CAST(YEAR(d.Data) AS NVARCHAR(4)), 2) AS MesAnoNome,
    YEAR(d.Data) * 100 + MONTH(d.Data) AS MesAnoNumero,
    MONTH(d.Data) * 100 + DAY(d.Data) AS MesDiaNumero,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) + '' '' + CAST(DAY(d.Data) AS NVARCHAR(2)) AS MesDiaNome,
    DATEFROMPARTS(YEAR(d.Data), MONTH(d.Data), 1) AS MesInicio,
    EOMONTH(d.Data) AS MesFim,
    (YEAR(d.Data) - YEAR(@DataInicial)) * 12 + (MONTH(d.Data) - MONTH(@DataInicial) + 1) AS MesIndice,
    (YEAR(d.Data) * 12 + MONTH(d.Data)) - (@AnoAtual * 12 + @MesAtual) AS MesesParaHoje,
    CASE 
        WHEN MONTH(d.Data) = @MesAtual THEN @TextoAtual 
        ELSE dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMMM'', @CultureInfo))
    END AS MesAtualNome,
    CASE 
        WHEN MONTH(d.Data) = @MesAtual THEN @TextoAtual 
        ELSE dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo))
    END AS MesAtualNomeAbreviado,
    CASE 
        WHEN (YEAR(d.Data) * 12 + MONTH(d.Data)) - (@AnoAtual * 12 + @MesAtual) = 0 THEN @TextoAtual 
        ELSE dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) + ''/'' + RIGHT(CAST(YEAR(d.Data) AS NVARCHAR(4)), 2)
    END AS MesAnoAtualNome,
    
    -- Trimestre
    DATEPART(QUARTER, d.Data) AS TrimestreNumero,
    @PrefixoTrimestre + CAST(DATEPART(QUARTER, d.Data) AS NVARCHAR(1)) AS TrimestreNome,
    @PrefixoTrimestre + CAST(DATEPART(QUARTER, d.Data) AS NVARCHAR(1)) + N'' '' + RIGHT(CAST(YEAR(d.Data) AS NVARCHAR(4)), 2) AS TrimestreAnoNome,
    YEAR(d.Data) * 100 + DATEPART(QUARTER, d.Data) AS TrimestreAnoNumero,
    DATEFROMPARTS(YEAR(d.Data), (DATEPART(QUARTER, d.Data) - 1) * 3 + 1, 1) AS TrimestreInicio,
    EOMONTH(DATEFROMPARTS(YEAR(d.Data), DATEPART(QUARTER, d.Data) * 3, 1)) AS TrimestreFim,
    (YEAR(d.Data) - YEAR(@DataInicial)) * 4 + DATEPART(QUARTER, d.Data) AS TrimestreIndice,
    (YEAR(d.Data) * 4 + DATEPART(QUARTER, d.Data)) - (@AnoAtual * 4 + DATEPART(QUARTER, @DataAtual)) AS TrimestresParaHoje,
    CASE 
        WHEN DATEPART(QUARTER, d.Data) = DATEPART(QUARTER, @DataAtual) THEN @TextoAtual 
        ELSE @PrefixoTrimestre + CAST(DATEPART(QUARTER, d.Data) AS NVARCHAR(1))
    END AS TrimestreAtual,
    CASE 
        WHEN (YEAR(d.Data) * 4 + DATEPART(QUARTER, d.Data)) - (@AnoAtual * 4 + DATEPART(QUARTER, @DataAtual)) = 0 THEN @TextoAtual 
        ELSE @PrefixoTrimestre + CAST(DATEPART(QUARTER, d.Data) AS NVARCHAR(1)) + N'' '' + RIGHT(CAST(YEAR(d.Data) AS NVARCHAR(4)), 2)
    END AS TrimestreAnoAtual,
    MONTH(d.Data) - ((DATEPART(QUARTER, d.Data) - 1) * 3) AS MesDoTrimestreNumero,
    
    -- Semana ISO (utilizando a função auxiliar)
    iso.SemanaISO AS SemanaDoAnoNumeroISO,
    iso.AnoISO,
    iso.AnoISO * 100 + iso.SemanaISO AS SemanaAnoNumeroISO,
    @PrefixoSemana + RIGHT(''0'' + CAST(iso.SemanaISO AS NVARCHAR(2)), 2) + N'' '' + CAST(iso.AnoISO AS NVARCHAR(4)) AS SemanaAnoNomeISO,
    iso.InicioDaSemanaISO AS SemanaInicioISO,
    iso.FimDaSemanaISO AS SemanaFimISO,
    CAST(DATEDIFF(DAY, DATEFROMPARTS(YEAR(@DataInicial), 1, 1), iso.InicioDaSemanaISO) / 7 AS INT) + 1 AS SemanaIndiceISO,
    CAST(DATEDIFF(DAY, DATEFROMPARTS(YEAR(@DataAtual), 1, 1), iso.InicioDaSemanaISO) / 7 AS INT) AS SemanasParaHojeISO,
    CASE 
        WHEN CAST(DATEDIFF(DAY, DATEFROMPARTS(YEAR(@DataAtual), 1, 1), iso.InicioDaSemanaISO) / 7 AS INT) = 0 THEN @TextoAtual 
        ELSE @PrefixoSemana + RIGHT(''0'' + CAST(iso.SemanaISO AS NVARCHAR(2)), 2) + N'' '' + CAST(iso.AnoISO AS NVARCHAR(4))
    END AS SemanaAtualISO,
    @PrefixoSemana + RIGHT(''0'' + CAST(iso.SemanaISO AS NVARCHAR(2)), 2) + N'' '' + CAST(iso.AnoISO AS NVARCHAR(4)) + N'': '' +
    FORMAT(iso.InicioDaSemanaISO, ''d'', @CultureInfo) + N''~'' + FORMAT(iso.FimDaSemanaISO, ''d'', @CultureInfo) AS SemanaPeriodoNome,
    CEILING(DAY(d.Data) / 7.0) AS SemanaDoMesNumero,
    
    -- Semestre
    CASE WHEN MONTH(d.Data) <= 6 THEN 1 ELSE 2 END AS SemestreNumero,
    @PrefixoSemestre + CAST(CASE WHEN MONTH(d.Data) <= 6 THEN 1 ELSE 2 END AS NVARCHAR(1)) + N'' '' + CAST(YEAR(d.Data) AS NVARCHAR(4)) AS SemestreAnoNome,
    YEAR(d.Data) * 100 + CASE WHEN MONTH(d.Data) <= 6 THEN 1 ELSE 2 END AS SemestreAnoNumero,
    (YEAR(d.Data) - YEAR(@DataInicial)) * 2 + CASE WHEN MONTH(d.Data) <= 6 THEN 1 ELSE 2 END AS SemestreIndice,
    (YEAR(d.Data) * 2 + CASE WHEN MONTH(d.Data) <= 6 THEN 1 ELSE 2 END) - (@AnoAtual * 2 + CASE WHEN @MesAtual <= 6 THEN 1 ELSE 2 END) AS SemestresParaHoje,
    CASE 
        WHEN (YEAR(d.Data) * 2 + CASE WHEN MONTH(d.Data) <= 6 THEN 1 ELSE 2 END) - (@AnoAtual * 2 + CASE WHEN @MesAtual <= 6 THEN 1 ELSE 2 END) = 0 THEN @TextoAtual 
        ELSE @PrefixoSemestre + CAST(CASE WHEN MONTH(d.Data) <= 6 THEN 1 ELSE 2 END AS NVARCHAR(1)) + N'' '' + CAST(YEAR(d.Data) AS NVARCHAR(4))
    END AS SemestreAtual,
    
    -- Bimestre
    CEILING(MONTH(d.Data) / 2.0) AS BimestreNumero,
    @PrefixoBimestre + CAST(CEILING(MONTH(d.Data) / 2.0) AS NVARCHAR(1)) + N'' '' + CAST(YEAR(d.Data) AS NVARCHAR(4)) AS BimestreAnoNome,
    YEAR(d.Data) * 100 + CEILING(MONTH(d.Data) / 2.0) AS BimestreAnoNumero,
    (YEAR(d.Data) - YEAR(@DataInicial)) * 6 + CEILING(MONTH(d.Data) / 2.0) AS BimestreIndice,
    (YEAR(d.Data) * 6 + CEILING(MONTH(d.Data) / 2.0)) - (@AnoAtual * 6 + CEILING(@MesAtual / 2.0)) AS BimestresParaHoje,
    CASE 
        WHEN (YEAR(d.Data) * 6 + CEILING(MONTH(d.Data) / 2.0)) - (@AnoAtual * 6 + CEILING(@MesAtual / 2.0)) = 0 THEN @TextoAtual 
        ELSE @PrefixoBimestre + CAST(CEILING(MONTH(d.Data) / 2.0) AS NVARCHAR(1)) + N'' '' + CAST(YEAR(d.Data) AS NVARCHAR(4))
    END AS BimestreAtual,
    
    -- Quinzena
    CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END AS QuinzenaDoMesNumero,
    MONTH(d.Data) * 10 + CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END AS QuinzenaMesNumero,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) + N'' '' + CAST(CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END AS NVARCHAR(1)) AS QuinzenaMesNome,
    YEAR(d.Data) * 10000 + MONTH(d.Data) * 100 + CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END AS QuinzenaMesAnoNumero,
    @PrefixoQuinzena + CAST(CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END AS NVARCHAR(1)) + N'' '' + 
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) + N'' '' + CAST(YEAR(d.Data) AS NVARCHAR(4)) AS QuinzenaMesAnoNome,
    (YEAR(d.Data) - YEAR(@DataInicial)) * 24 + (MONTH(d.Data) - MONTH(@DataInicial)) * 2 + CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END AS QuinzenaIndice,
    (YEAR(d.Data) * 24 + MONTH(d.Data) * 2 + CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END) - 
    (@AnoAtual * 24 + @MesAtual * 2 + CASE WHEN DAY(@DataAtual) <= 15 THEN 1 ELSE 2 END) AS QuinzenasParaHoje,
    CASE 
        WHEN (YEAR(d.Data) * 24 + MONTH(d.Data) * 2 + CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END) - 
            (@AnoAtual * 24 + @MesAtual * 2 + CASE WHEN DAY(@DataAtual) <= 15 THEN 1 ELSE 2 END) = 0 THEN @TextoAtual 
        ELSE dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) + N'' '' + CAST(CASE WHEN DAY(d.Data) <= 15 THEN 1 ELSE 2 END AS NVARCHAR(1))
    END AS QuinzenaAtual,
    
    -- Fechamento
    CASE 
        WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data 
        ELSE DATEADD(MONTH, 1, d.Data)
    END AS DataDeFechamentoRef,
    YEAR(CASE WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data ELSE DATEADD(MONTH, 1, d.Data) END) AS AnoFechamento,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(CASE WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data ELSE DATEADD(MONTH, 1, d.Data) END), 1), ''MMMM'', @CultureInfo)) AS MesFechamentoNome,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(CASE WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data ELSE DATEADD(MONTH, 1, d.Data) END), 1), ''MMM'', @CultureInfo)) AS MesFechamentoNomeAbreviado,
    MONTH(CASE WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data ELSE DATEADD(MONTH, 1, d.Data) END) AS MesFechamentoNumero,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(CASE WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data ELSE DATEADD(MONTH, 1, d.Data) END), 1), ''MMM'', @CultureInfo)) + ''/'' +
    RIGHT(CAST(YEAR(CASE WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data ELSE DATEADD(MONTH, 1, d.Data) END) AS NVARCHAR(4)), 2) AS MesAnoFechamentoNome,
    YEAR(CASE WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data ELSE DATEADD(MONTH, 1, d.Data) END) * 100 + 
    MONTH(CASE WHEN DAY(d.Data) <= @DiaInicioMesFechamento THEN d.Data ELSE DATEADD(MONTH, 1, d.Data) END) AS MesAnoFechamentoNumero,
    
    -- Estação
    CASE 
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 321 AND 620 THEN 1
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 621 AND 921 THEN 2
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 922 AND 1221 THEN 3
        ELSE 4
    END AS EstacaoNorteNumero,
    CASE 
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 321 AND 620 THEN @TextoPrimavera
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 621 AND 921 THEN @TextoVerao
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 922 AND 1221 THEN @TextoOutono
        ELSE @TextoInverno
    END AS EstacaoNorteNome,
    CASE 
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 321 AND 620 THEN 1
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 621 AND 921 THEN 2
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 922 AND 1221 THEN 3
        ELSE 4
    END AS EstacaoSulNumero,
    CASE 
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 321 AND 620 THEN @TextoOutono
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 621 AND 921 THEN @TextoInverno
        WHEN MONTH(d.Data) * 100 + DAY(d.Data) BETWEEN 922 AND 1221 THEN @TextoPrimavera
        ELSE @TextoVerao
    END AS EstacaoSulNome,
    
    -- Dias Úteis e Feriados
    dbo.fn_CapitalizarTexto(f.NomeFeriado) AS Feriado,
    CONVERT(BIT, dbo.fn_IsDiaUtil(d.Data, CASE WHEN f.NomeFeriado IS NULL THEN 0 ELSE 1 END)) AS DiaUtilNumero,
    CASE WHEN dbo.fn_IsDiaUtil(d.Data, CASE WHEN f.NomeFeriado IS NULL THEN 0 ELSE 1 END) = 1 THEN @TextoDiaUtil ELSE @TextoDiaNaoUtil END AS DiaUtilNome,
    
    -- Ano Fiscal
    YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) AS AnoFiscalInicialNumero,
    YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) + 1 AS AnoFiscalFinalNumero,
    @PrefixoAnoFiscal + N'' '' + CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) AS NVARCHAR(4)) + N''-'' + 
    CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) + 1 AS NVARCHAR(4)) AS AnoFiscal,
    DATEFROMPARTS(
        YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)), 
        CASE WHEN @MesFimAnoFiscal = 12 THEN 1 ELSE @MesFimAnoFiscal + 1 END, 
        1
    ) AS AnoFiscalInicio,
    EOMONTH(DATEFROMPARTS(
		YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) + CASE WHEN @MesFimAnoFiscal = 12 THEN 0 ELSE 1 END,
		@MesFimAnoFiscal, 
		1
	)) AS AnoFiscalFim,
    CASE 
        WHEN YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) = @AnoFiscalAtual THEN @TextoAtual 
        ELSE @PrefixoAnoFiscal + N'' '' + CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) AS NVARCHAR(4)) + N''-'' + 
             CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) + 1 AS NVARCHAR(4))
    END AS AnoFiscalAtual,
    YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) - @AnoFiscalAtual AS AnosFiscaisParaHoje,
    
    -- Mês Fiscal
    MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) AS MesFiscalNumero,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMMM'', @CultureInfo)) AS MesFiscalNome,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) AS MesFiscalNomeAbreviado,
    CASE 
        WHEN d.Data = @DataAtual THEN @TextoAtual 
        ELSE dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMMM'', @CultureInfo))
    END AS MesFiscalAtual,
    dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) + N'' '' + @PrefixoAnoFiscal + N'' '' + 
    CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) AS NVARCHAR(4)) + N''-'' + 
    CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) + 1 AS NVARCHAR(4)) AS MesAnoFiscalNome,
    YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) * 100 + MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) AS MesAnoFiscalNumero,
    CASE 
        WHEN YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) = @AnoFiscalAtual AND d.Data = @DataAtual THEN @TextoAtual 
        ELSE dbo.fn_CapitalizarTexto(FORMAT(DATEFROMPARTS(2020, MONTH(d.Data), 1), ''MMM'', @CultureInfo)) + N'' '' + @PrefixoAnoFiscal + N'' '' + 
        CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) AS NVARCHAR(4)) + N''-'' + 
        CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) + 1 AS NVARCHAR(4))
    END AS MesAnoFiscalAtual,
    (YEAR(d.Data) * 12 + MONTH(d.Data)) - (@AnoAtual * 12 + @MesAtual) AS MesesFiscaisParaHoje,
    
    -- Trimestre Fiscal
    CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) AS TrimestreFiscalNumero,
    @PrefixoTrimestreFiscal + N'' '' + CAST(CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) AS NVARCHAR(1)) AS TrimestreFiscalNome,
    MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) - 3 * (CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) - 1) AS MesDoTrimestreFiscalNumero,
    @PrefixoTrimestreFiscal + N'' '' + CAST(CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) AS NVARCHAR(1)) + N'' | '' + 
    @PrefixoAnoFiscal + N'' '' + CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) AS NVARCHAR(4)) + N''-'' + 
    CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) + 1 AS NVARCHAR(4)) AS AnoTrimestreFiscalNome,
    YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) * 100 + CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) AS AnoTrimestreFiscalNumero,
    DATEADD(MONTH, 
        1 - (MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) - 3 * (CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) - 1)), 
        d.Data
    ) AS TrimestreFiscalInicio,
    DATEADD(MONTH, 
        3 - (MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) - 3 * (CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) - 1)),
        d.Data
    ) AS TrimestreFiscalFim,
    (YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) - @AnoFiscalAtual) * 4 + 
    (CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) - CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, @DataAtual)) / 3.0)) AS TrimestresFiscaisParaHoje,
    CASE 
        WHEN (YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) - @AnoFiscalAtual) * 4 + 
         (CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) - CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, @DataAtual)) / 3.0)) = 0 THEN @TextoAtual 
        ELSE @PrefixoTrimestreFiscal + N'' '' + CAST(CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) AS NVARCHAR(1)) + N'' | '' + 
        @PrefixoAnoFiscal + N'' '' + CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) AS NVARCHAR(4)) + N''-'' + 
        CAST(YEAR(DATEADD(MONTH, 12 - @MesFimAnoFiscal, d.Data)) + 1 AS NVARCHAR(4))
    END AS TrimestreFiscalAtual,
    DATEDIFF(DAY, 
        DATEADD(MONTH, 
            1 - (MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) - 3 * (CEILING(MONTH(DATEADD(MONTH, -@MesFimAnoFiscal, d.Data)) / 3.0) - 1)), 
            d.Data
        ), 
        d.Data
    ) + 1 AS DiaDoTrimestreFiscal
FROM 
    #Datas d
CROSS APPLY 
    dbo.fn_CalcularSemanaISO(d.Data) iso
LEFT JOIN 
    ' + @NomeTabelaFeriadosCompleto + ' f ON d.Data = f.Data AND f.CultureInfo = @CultureInfoFeriados
ORDER BY 
    d.Data';

EXEC sp_executesql @SQL,
    N'@DataInicial DATE, @DataFinal DATE, @DataAtual DATE, @AnoAtual INT, @MesAtual INT, @AnoFiscalAtual INT, 
      @TextoAtual NVARCHAR(20), @PrefixoTrimestre NVARCHAR(2), @PrefixoSemana NVARCHAR(2), 
      @PrefixoSemestre NVARCHAR(2), @PrefixoBimestre NVARCHAR(2), @PrefixoQuinzena NVARCHAR(2),
      @TextoPrimavera NVARCHAR(20), @TextoVerao NVARCHAR(20), @TextoOutono NVARCHAR(20), @TextoInverno NVARCHAR(20),
      @TextoDiaUtil NVARCHAR(30), @TextoDiaNaoUtil NVARCHAR(30), @MesFimAnoFiscal INT, @DiaInicioMesFechamento INT,
      @CultureInfo NVARCHAR(10), @CultureInfoFeriados NVARCHAR(10), @ZWS NVARCHAR(1),
      @PrefixoAnoFiscal NVARCHAR(30), @PrefixoTrimestreFiscal NVARCHAR(30)',
    @DataInicial, @DataFinal, @DataAtual, @AnoAtual, @MesAtual, @AnoFiscalAtual,
    @TextoAtual, @PrefixoTrimestre, @PrefixoSemana, 
    @PrefixoSemestre, @PrefixoBimestre, @PrefixoQuinzena,
    @TextoPrimavera, @TextoVerao, @TextoOutono, @TextoInverno,
    @TextoDiaUtil, @TextoDiaNaoUtil, @MesFimAnoFiscal, @DiaInicioMesFechamento,
    @CultureInfo, @CultureInfoFeriados, @ZWS,
    @PrefixoAnoFiscal, @PrefixoTrimestreFiscal;

-- Criar índices para melhorar a performance
SET @SQL = N'
CREATE INDEX IX_' + @SchemaTabela + '_' + @NomeTabelaCalendario + '_Ano ON ' + @NomeTabelaCompleto + '(Ano);
CREATE INDEX IX_' + @SchemaTabela + '_' + @NomeTabelaCalendario + '_MesAno ON ' + @NomeTabelaCompleto + '(Ano, MesNumero);
CREATE INDEX IX_' + @SchemaTabela + '_' + @NomeTabelaCalendario + '_TrimestreAno ON ' + @NomeTabelaCompleto + '(Ano, TrimestreNumero);
CREATE INDEX IX_' + @SchemaTabela + '_' + @NomeTabelaCalendario + '_DiaUtil ON ' + @NomeTabelaCompleto + '(DiaUtilNumero);
CREATE INDEX IX_' + @SchemaTabela + '_' + @NomeTabelaCalendario + '_AnoFiscal ON ' + @NomeTabelaCompleto + '(AnoFiscalInicialNumero);';

EXEC sp_executesql @SQL;

-- Excluir a tabela de feriados se o parâmetro @ManterTabelaFeriados for 0
IF @ManterTabelaFeriados = 0
BEGIN
    SET @SQL = N'IF OBJECT_ID(''' + @NomeTabelaFeriadosCompleto + ''', ''U'') IS NOT NULL
        DROP TABLE ' + @NomeTabelaFeriadosCompleto;
    
    EXEC sp_executesql @SQL;
    
    PRINT 'Tabela de feriados ' + @NomeTabelaFeriadosCompleto + ' excluída conforme solicitado.';
END
ELSE
BEGIN
    PRINT 'Tabela de feriados ' + @NomeTabelaFeriadosCompleto + ' mantida conforme solicitado.';
END

/*
-- Descomentar caso queira traduzir os nomes das colunas também
-- Traduzir nomes das colunas se o idioma não for pt-BR
IF @CultureInfo <> 'pt-BR'
BEGIN
    PRINT 'Iniciando processo de tradução dos nomes das colunas para ' + @CultureInfo;
    
    DECLARE @NomeColuna NVARCHAR(128);
    DECLARE @NomeColunaOriginal NVARCHAR(128);
    DECLARE @NomeColunaTraduzido NVARCHAR(128);
    DECLARE @SQL_Rename NVARCHAR(MAX);
    
    -- Criar um cursor para iterar através das colunas da tabela
    DECLARE ColunaCursor CURSOR FOR
    SELECT name
    FROM sys.columns
    WHERE object_id = OBJECT_ID(@NomeTabelaCompleto);
    
    OPEN ColunaCursor;
    FETCH NEXT FROM ColunaCursor INTO @NomeColuna;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Obter o nome traduzido da coluna
        SET @NomeColunaOriginal = @NomeColuna;
        SET @NomeColunaTraduzido = DW.fn_ObterNomeTraduzido(@NomeColunaOriginal, 'pt-BR', @CultureInfo);
        
        -- Apenas renomear se a tradução for diferente do nome original
        IF @NomeColunaOriginal <> @NomeColunaTraduzido
        BEGIN
            -- Construir e executar o comando sp_rename
            SET @SQL_Rename = N'EXEC sp_rename ''' + @NomeTabelaCompleto + '.' + @NomeColunaOriginal + ''', ''' + @NomeColunaTraduzido + ''', ''COLUMN''';
            EXEC sp_executesql @SQL_Rename;
            
            PRINT 'Coluna renomeada: ' + @NomeColunaOriginal + ' -> ' + @NomeColunaTraduzido;
        END
        
        FETCH NEXT FROM ColunaCursor INTO @NomeColuna;
    END
    
    CLOSE ColunaCursor;
    DEALLOCATE ColunaCursor;
    
    PRINT 'Processo de tradução dos nomes das colunas concluído para ' + @CultureInfo;
END
*/

-- Estatísticas da tabela
PRINT '=== Estatísticas da tabela ' + @NomeTabelaCompleto + ' ==='
PRINT '----------------------------------------------------'

SET @SQL = N'
SELECT ''Total de registros'' AS Metrica, CAST(COUNT(*) AS VARCHAR(20)) AS Valor FROM ' + @NomeTabelaCompleto + '
UNION ALL
SELECT ''Data inicial'' AS Metrica, CONVERT(VARCHAR(20), MIN(Data), 103) AS Valor FROM ' + @NomeTabelaCompleto + '
UNION ALL
SELECT ''Data final'' AS Metrica, CONVERT(VARCHAR(20), MAX(Data), 103) AS Valor FROM ' + @NomeTabelaCompleto + '
UNION ALL
SELECT ''Total de anos'' AS Metrica, CAST(COUNT(DISTINCT Ano) AS VARCHAR(20)) AS Valor FROM ' + @NomeTabelaCompleto + '
UNION ALL
SELECT ''Método de definição de período'' AS Metrica, 
    CASE WHEN ' + CAST(@UsarTabelaFato AS VARCHAR(1)) + ' = 1 THEN ''Baseado na tabela fato ' + @NomeTabelaFato + ''' ELSE ''Valores fixos'' END AS Valor
UNION ALL
SELECT ''Idioma/cultura principal'' AS Metrica, ''' + @CultureInfo + ''' AS Valor
UNION ALL
SELECT ''Idioma/cultura dos feriados'' AS Metrica, ''' + @CultureInfoFeriados + ''' AS Valor
UNION ALL
SELECT ''Tabela de feriados utilizada'' AS Metrica, ''' + @NomeTabelaFeriadosCompleto + ''' AS Valor
UNION ALL
SELECT ''Tabela de feriados após processamento'' AS Metrica, CASE WHEN ' + CAST(@ManterTabelaFeriados AS VARCHAR(1)) + ' = 1 THEN ''Mantida'' ELSE ''Excluída'' END AS Valor';

EXEC sp_executesql @SQL;

-- Consulta exemplo dos resultados
PRINT 'Exemplo dos últimos 10 registros:'
SET @SQL = N'SELECT TOP 10 * FROM ' + @NomeTabelaCompleto + ' ORDER BY Data DESC';
EXEC sp_executesql @SQL;

-- Resumo por ano
PRINT 'Resumo de dias úteis e feriados por ano:'
SET @SQL = N'
SELECT 
    Ano,
    COUNT(*) AS ''Total de Dias'',
    SUM(CAST(DiaUtilNumero AS INT)) AS ''Dias Úteis'',
    COUNT(*) - SUM(CAST(DiaUtilNumero AS INT)) AS ''Dias Não Úteis'',
    STUFF((
        SELECT '', '' + Feriado
        FROM ' + @NomeTabelaCompleto + ' c2
        WHERE c2.Ano = c1.Ano AND c2.Feriado IS NOT NULL
        ORDER BY c2.Data
        FOR XML PATH('''')
    ), 1, 2, '''') AS ''Feriados''
FROM 
    ' + @NomeTabelaCompleto + ' c1
GROUP BY 
    Ano
ORDER BY 
    Ano';

EXEC sp_executesql @SQL;

-- Limpeza
DROP TABLE #Datas;

-- Informações finais
PRINT '✓ Tabela ' + @NomeTabelaCompleto + ' criada com sucesso!'
PRINT '✓ Parâmetros utilizados:'
PRINT '   - Nome da tabela: ' + @NomeTabelaCompleto
PRINT '   - Tabela de feriados: ' + @NomeTabelaFeriadosCompleto
PRINT '   - Idioma/cultura principal: ' + @CultureInfo
PRINT '   - Idioma/cultura dos feriados: ' + @CultureInfoFeriados
PRINT '   - Período: ' + CONVERT(VARCHAR(20), @DataInicial, 103) + ' até ' + CONVERT(VARCHAR(20), @DataFinal, 103)
PRINT '✓ Para acessar a tabela, execute: SELECT * FROM ' + @NomeTabelaCompleto + ' WHERE <condições>';