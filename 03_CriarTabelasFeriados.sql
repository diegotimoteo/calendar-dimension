--======================================================================================================
-- Script para criar tabela de feriados
-- Versão 1.0
-- Autor: Diego Timóteo
-- Deve ser executado após 02_CriarTabelaTraducaoColunas.sql e antes de 04_CriarTabelaCalendario.sql
--======================================================================================================


-- Configurações iniciais
SET NOCOUNT ON;
GO

-- =============================================
-- PARÂMETROS DE CONFIGURAÇÃO
-- =============================================

-- Parâmetros de esquema e nomes de tabelas
DECLARE @SchemaTabelas NVARCHAR(128) = 'DW';         -- Schema onde as tabelas serão criadas
DECLARE @NomeTabelaFeriadosFixos NVARCHAR(128) = 'dimFeriadosFixos';     -- Nome da tabela de feriados fixos
DECLARE @NomeTabelaFeriadosMoveis NVARCHAR(128) = 'dimFeriadosMoveis';   -- Nome da tabela de feriados móveis
DECLARE @NomeTabelaFeriados NVARCHAR(128) = 'dimFeriados';               -- Nome da tabela de feriados processados

-- Construção dos nomes completos das tabelas
DECLARE @NomeCompletoFeriadosFixos NVARCHAR(257) = QUOTENAME(@SchemaTabelas) + '.' + QUOTENAME(@NomeTabelaFeriadosFixos);
DECLARE @NomeCompletoFeriadosMoveis NVARCHAR(257) = QUOTENAME(@SchemaTabelas) + '.' + QUOTENAME(@NomeTabelaFeriadosMoveis);
DECLARE @NomeCompletoFeriados NVARCHAR(257) = QUOTENAME(@SchemaTabelas) + '.' + QUOTENAME(@NomeTabelaFeriados);

-- Opção para remover tabelas auxiliares ao final do processamento
DECLARE @RemoverTabelasAuxiliares BIT = 1;           -- 0 = Manter tabelas auxiliares, 1 = Remover após processamento

-- Parâmetros para internacionalização
DECLARE @CultureInfoFeriados NVARCHAR(10) = 'pt-BR'; -- Idioma específico para feriados
-- Opções disponíveis para feriados:
-- 'pt-BR' = Feriados brasileiros
-- 'en-US' = Feriados dos Estados Unidos
-- 'es-ES' = Feriados da Espanha
-- 'custom' = Utiliza tabela personalizada de feriados (requer configuração adicional)

-- Configuração para determinar o intervalo de datas - para cálculo de feriados móveis
DECLARE @DataInicial DATE = '2000-01-01';
DECLARE @DataFinal DATE = '2050-12-31';

-- =============================================
-- FIM DE PARÂMETROS DE CONFIGURAÇÃO
-- =============================================

-- Verificar e criar o schema se não existir
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = @SchemaTabelas)
BEGIN
    DECLARE @SQL NVARCHAR(MAX) = N'CREATE SCHEMA ' + QUOTENAME(@SchemaTabelas);
    EXEC sp_executesql @SQL;
END

-- Criar tabelas permanentes de feriados
DECLARE @SQLDrop NVARCHAR(MAX);
DECLARE @SQLCreate NVARCHAR(MAX);

-- Tabela de feriados fixos
SET @SQLDrop = N'IF OBJECT_ID(' + QUOTENAME(@NomeCompletoFeriadosFixos, '''') + N') IS NOT NULL
    DROP TABLE ' + @NomeCompletoFeriadosFixos;
EXEC sp_executesql @SQLDrop;

SET @SQLCreate = N'
CREATE TABLE ' + @NomeCompletoFeriadosFixos + N' (
    Dia INT,
    Mes INT,
    NomeFeriado NVARCHAR(200),
    CultureInfo NVARCHAR(10),
    PRIMARY KEY (Dia, Mes, CultureInfo)
)';
EXEC sp_executesql @SQLCreate;

-- Popular tabela de feriados fixos específicos por idioma
-- Feriados Brasileiros
SET @SQL = N'
INSERT INTO ' + @NomeCompletoFeriadosFixos + N' (Dia, Mes, NomeFeriado, CultureInfo) VALUES
    (01, 01, N''Confraternização Universal'', ''pt-BR''),
    (25, 01, N''Aniversário da Cidade'', ''pt-BR''),
    (21, 04, N''Tiradentes'', ''pt-BR''),
    (01, 05, N''Dia do Trabalhador'', ''pt-BR''),
    (09, 07, N''Revolução Constitucionalista'', ''pt-BR''),
    (07, 09, N''Independência do Brasil'', ''pt-BR''),
    (12, 10, N''N. Srª Aparecida'', ''pt-BR''),
    (02, 11, N''Finados'', ''pt-BR''),
    (15, 11, N''Proclamação da República'', ''pt-BR''),
    (20, 11, N''Consciência Negra'', ''pt-BR''),
    (24, 12, N''Véspera de Natal'', ''pt-BR''),
    (25, 12, N''Natal'', ''pt-BR''),
    (31, 12, N''Véspera de Ano Novo'', ''pt-BR'')';
EXEC sp_executesql @SQL;

-- Feriados dos Estados Unidos
SET @SQL = N'
INSERT INTO ' + @NomeCompletoFeriadosFixos + N' (Dia, Mes, NomeFeriado, CultureInfo) VALUES
    (01, 01, N''New Year''''s Day'', ''en-US''),
    (17, 01, N''Martin Luther King Jr. Day'', ''en-US''),
    (21, 02, N''Presidents'''' Day'', ''en-US''),
    (30, 05, N''Memorial Day'', ''en-US''),
    (04, 07, N''Independence Day'', ''en-US''),
    (05, 09, N''Labor Day'', ''en-US''),
    (10, 10, N''Columbus Day'', ''en-US''),
    (11, 11, N''Veterans Day'', ''en-US''),
    (24, 11, N''Thanksgiving Day'', ''en-US''),
    (24, 12, N''Christmas Eve'', ''en-US''),
    (25, 12, N''Christmas Day'', ''en-US''),
    (31, 12, N''New Year''''s Eve'', ''en-US'')';
EXEC sp_executesql @SQL;

-- Feriados da Espanha
SET @SQL = N'
INSERT INTO ' + @NomeCompletoFeriadosFixos + N' (Dia, Mes, NomeFeriado, CultureInfo) VALUES
    (01, 01, N''Año Nuevo'', ''es-ES''),
    (06, 01, N''Día de Reyes'', ''es-ES''),
    (01, 05, N''Día del Trabajo'', ''es-ES''),
    (15, 08, N''Asunción de la Virgen'', ''es-ES''),
    (12, 10, N''Fiesta Nacional de España'', ''es-ES''),
    (01, 11, N''Todos los Santos'', ''es-ES''),
    (06, 12, N''Día de la Constitución'', ''es-ES''),
    (08, 12, N''Inmaculada Concepción'', ''es-ES''),
    (24, 12, N''Nochebuena'', ''es-ES''),
    (25, 12, N''Navidad'', ''es-ES''),
    (31, 12, N''Nochevieja'', ''es-ES'')';
EXEC sp_executesql @SQL;

-- Criar tabela para feriados calculados para cada ano
SET @SQLDrop = N'IF OBJECT_ID(' + QUOTENAME(@NomeCompletoFeriados, '''') + N') IS NOT NULL
    DROP TABLE ' + @NomeCompletoFeriados;
EXEC sp_executesql @SQLDrop;

SET @SQLCreate = N'
CREATE TABLE ' + @NomeCompletoFeriados + N' (
    Data DATE,
    NomeFeriado NVARCHAR(200),
    CultureInfo NVARCHAR(10),
    PRIMARY KEY (Data, CultureInfo)
)';
EXEC sp_executesql @SQLCreate;

-- Criar tabela para feriados móveis (baseados na Páscoa)
SET @SQLDrop = N'IF OBJECT_ID(' + QUOTENAME(@NomeCompletoFeriadosMoveis, '''') + N') IS NOT NULL
    DROP TABLE ' + @NomeCompletoFeriadosMoveis;
EXEC sp_executesql @SQLDrop;

SET @SQLCreate = N'
CREATE TABLE ' + @NomeCompletoFeriadosMoveis + N' (
    DiasRelativosPascoa INT,
    NomeFeriado NVARCHAR(200),
    CultureInfo NVARCHAR(10),
    PRIMARY KEY (DiasRelativosPascoa, CultureInfo)
)';
EXEC sp_executesql @SQLCreate;

-- Definir feriados móveis para cada cultura
-- Feriados móveis brasileiros
SET @SQL = N'
INSERT INTO ' + @NomeCompletoFeriadosMoveis + N' (DiasRelativosPascoa, NomeFeriado, CultureInfo) VALUES
    (-47, N''Carnaval'', ''pt-BR''),
    (-2, N''Sexta-Feira Santa'', ''pt-BR''),
    (0, N''Páscoa'', ''pt-BR''),
    (60, N''Corpus Christi'', ''pt-BR'')';
EXEC sp_executesql @SQL;

-- Feriados móveis EUA
SET @SQL = N'
INSERT INTO ' + @NomeCompletoFeriadosMoveis + N' (DiasRelativosPascoa, NomeFeriado, CultureInfo) VALUES
    (-2, N''Good Friday'', ''en-US''),
    (0, N''Easter Sunday'', ''en-US'')';
EXEC sp_executesql @SQL;

-- Feriados móveis Espanha
SET @SQL = N'
INSERT INTO ' + @NomeCompletoFeriadosMoveis + N' (DiasRelativosPascoa, NomeFeriado, CultureInfo) VALUES
    (-2, N''Viernes Santo'', ''es-ES''),
    (0, N''Domingo de Pascua'', ''es-ES''),
    (60, N''Corpus Christi'', ''es-ES'')';
EXEC sp_executesql @SQL;

-- Processar feriados fixos para cada ano no intervalo
SET @SQL = N'
INSERT INTO ' + @NomeCompletoFeriados + N' (Data, NomeFeriado, CultureInfo)
SELECT 
    DATEFROMPARTS(Ano, Mes, Dia) AS Data,
    NomeFeriado,
    f.CultureInfo
FROM ' + @NomeCompletoFeriadosFixos + N' f
CROSS JOIN (
    SELECT DISTINCT YEAR(Data) AS Ano
    FROM (
        SELECT @DataInicial AS Data
        UNION ALL
        SELECT DATEADD(YEAR, n1.n + n2.n, @DataInicial)
        FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) n1(n)
        CROSS JOIN (VALUES (0),(10),(20),(30),(40)) n2(n)
        WHERE DATEADD(YEAR, n1.n + n2.n, @DataInicial) <= @DataFinal
    ) YearRange
) Anos
WHERE DATEFROMPARTS(Ano, Mes, Dia) BETWEEN @DataInicial AND @DataFinal';
EXEC sp_executesql @SQL, N'@DataInicial DATE, @DataFinal DATE', @DataInicial, @DataFinal;

-- Calcular e inserir feriados móveis para cada ano no intervalo
DECLARE @Ano INT = YEAR(@DataInicial);
DECLARE @AnoFim INT = YEAR(@DataFinal);

WHILE @Ano <= @AnoFim
BEGIN
    -- Obter data da Páscoa para o ano atual
    DECLARE @DataPascoa DATE = dbo.fn_CalcularPascoa(@Ano);
    
    -- Inserir feriados móveis baseados na Páscoa
    SET @SQL = N'
    INSERT INTO ' + @NomeCompletoFeriados + N' (Data, NomeFeriado, CultureInfo)
    SELECT 
        DATEADD(DAY, fm.DiasRelativosPascoa, @DataPascoa) AS Data,
        fm.NomeFeriado,
        fm.CultureInfo
    FROM ' + @NomeCompletoFeriadosMoveis + N' fm
    WHERE DATEADD(DAY, fm.DiasRelativosPascoa, @DataPascoa) BETWEEN @DataInicial AND @DataFinal
    AND NOT EXISTS (
        SELECT 1 FROM ' + @NomeCompletoFeriados + N' f 
        WHERE f.Data = DATEADD(DAY, fm.DiasRelativosPascoa, @DataPascoa)
        AND f.CultureInfo = fm.CultureInfo
    )';
    
    EXEC sp_executesql @SQL, N'@DataPascoa DATE, @DataInicial DATE, @DataFinal DATE', 
                      @DataPascoa, @DataInicial, @DataFinal;
    
    SET @Ano = @Ano + 1;
END;

-- Tratar colisões (feriados que caem no mesmo dia)
-- Identificar datas com múltiplos feriados na mesma cultura
SET @SQL = N'
WITH FeriadosDuplicados AS (
    SELECT Data, CultureInfo
    FROM ' + @NomeCompletoFeriados + N'
    GROUP BY Data, CultureInfo
    HAVING COUNT(*) > 1
)
-- Para cada data/cultura com duplicatas, concatenar os nomes dos feriados
UPDATE f
SET NomeFeriado = (
    SELECT STUFF((
        SELECT '' / '' + NomeFeriado
        FROM ' + @NomeCompletoFeriados + N' 
        WHERE Data = fd.Data AND CultureInfo = fd.CultureInfo
        FOR XML PATH('''')), 1, 3, '''')
)
FROM ' + @NomeCompletoFeriados + N' f
JOIN FeriadosDuplicados fd ON f.Data = fd.Data AND f.CultureInfo = fd.CultureInfo
WHERE f.NomeFeriado = (
    SELECT MIN(NomeFeriado) 
    FROM ' + @NomeCompletoFeriados + N' 
    WHERE Data = f.Data AND CultureInfo = f.CultureInfo
)';

EXEC sp_executesql @SQL;

-- Remover feriados duplicados após a concatenação
SET @SQL = N'
WITH RankFeriados AS (
    SELECT 
        Data, 
        CultureInfo,
        NomeFeriado,
        ROW_NUMBER() OVER (PARTITION BY Data, CultureInfo ORDER BY NomeFeriado) AS rn
    FROM ' + @NomeCompletoFeriados + N'
)
DELETE FROM RankFeriados WHERE rn > 1';

EXEC sp_executesql @SQL;

-- Estatísticas
SET @SQL = N'
SELECT ''' + @SchemaTabelas + '.' + @NomeTabelaFeriadosFixos + ''' AS Tabela, COUNT(*) AS TotalRegistros FROM ' + @NomeCompletoFeriadosFixos + N'
UNION ALL
SELECT ''' + @SchemaTabelas + '.' + @NomeTabelaFeriadosMoveis + ''' AS Tabela, COUNT(*) AS TotalRegistros FROM ' + @NomeCompletoFeriadosMoveis + N'
UNION ALL
SELECT ''' + @SchemaTabelas + '.' + @NomeTabelaFeriados + ''' AS Tabela, COUNT(*) AS TotalRegistros FROM ' + @NomeCompletoFeriados;

EXEC sp_executesql @SQL;

PRINT '✓ Tabelas de feriados criadas com sucesso!'
PRINT '✓ Schema utilizado: ' + @SchemaTabelas
PRINT '✓ Nomes das tabelas: '
PRINT '   - ' + @NomeTabelaFeriadosFixos + ' (feriados fixos)'
PRINT '   - ' + @NomeTabelaFeriadosMoveis + ' (feriados móveis)'
PRINT '   - ' + @NomeTabelaFeriados + ' (feriados processados)'
PRINT '✓ Foram processados feriados de ' + CAST(YEAR(@DataInicial) AS VARCHAR) + ' até ' + CAST(YEAR(@DataFinal) AS VARCHAR)
PRINT '✓ Para visualizar feriados, execute: SELECT * FROM ' + @SchemaTabelas + '.' + @NomeTabelaFeriados + ' WHERE CultureInfo = ''sua_cultura'' AND YEAR(Data) = seu_ano'

-- Remover tabelas auxiliares se configurado
IF @RemoverTabelasAuxiliares = 1
BEGIN
    SET @SQL = N'DROP TABLE ' + @NomeCompletoFeriadosFixos;
    EXEC sp_executesql @SQL;
    
    SET @SQL = N'DROP TABLE ' + @NomeCompletoFeriadosMoveis;
    EXEC sp_executesql @SQL;
    
    PRINT '✓ Tabelas auxiliares removidas conforme configuração'
    PRINT '   As tabelas ' + @NomeTabelaFeriadosFixos + ' e ' + @NomeTabelaFeriadosMoveis + ' foram removidas'
    PRINT '   Apenas a tabela ' + @NomeTabelaFeriados + ' foi mantida com todos os feriados processados'
END
ELSE
BEGIN
    PRINT '✓ Todas as tabelas foram mantidas conforme configuração'
    PRINT '   Você pode usar as tabelas auxiliares para manutenção futura dos feriados'
    PRINT '   Para remover as tabelas auxiliares, defina @RemoverTabelasAuxiliares = 1 no início do script'
END

PRINT 'Agora execute o script 04_CriarTabelaCalendario.sql para criar a tabela de calendário'