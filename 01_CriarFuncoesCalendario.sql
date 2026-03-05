--==========================================================================================================================================
-- Script para criar funções auxiliares para a tabela calendário
-- Versão 1.0
-- Autor: Diego Timóteo
-- Deve ser excutado antes dos scripts 02_CriarTabelaTraducaoColunas.sql, 03_CriarTabelasFeriados.sql e 04_CriarTabelaCalendario.sql
--==========================================================================================================================================

-- Configurações iniciais
SET NOCOUNT ON;
GO

-- Verificar e criar o schema DW se não existir
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'DW')
BEGIN
    EXEC('CREATE SCHEMA DW')
END
GO

-- 1. Função para calcular a data da Páscoa (Algoritmo de Gauss/Butcher)
IF OBJECT_ID('dbo.fn_CalcularPascoa') IS NOT NULL
    DROP FUNCTION dbo.fn_CalcularPascoa;
GO

CREATE FUNCTION dbo.fn_CalcularPascoa(@Ano INT)
RETURNS DATE
AS
BEGIN
    -- Algoritmo de Gauss/Butcher para cálculo da Páscoa
    DECLARE @a INT = @Ano % 19;
    DECLARE @b INT = @Ano / 100;
    DECLARE @c INT = @Ano % 100;
    DECLARE @d INT = @b / 4;
    DECLARE @e INT = @b % 4;
    DECLARE @f INT = (@b + 8) / 25;
    DECLARE @g INT = (@b - @f + 1) / 3;
    DECLARE @h INT = (19 * @a + @b - @d - @g + 15) % 30;
    DECLARE @i INT = @c / 4;
    DECLARE @k INT = @c % 4;
    DECLARE @L INT = (32 + 2 * @e + 2 * @i - @h - @k) % 7;
    DECLARE @m INT = (@a + 11 * @h + 22 * @L) / 451;
    DECLARE @month INT = (@h + @L - 7 * @m + 114) / 31;
    DECLARE @day INT = ((@h + @L - 7 * @m + 114) % 31) + 1;

    RETURN DATEFROMPARTS(@Ano, @month, @day);
END;
GO

-- 2. Função para calcular o número da semana ISO - VERSÃO CORRIGIDA
IF OBJECT_ID('dbo.fn_CalcularSemanaISO') IS NOT NULL
    DROP FUNCTION dbo.fn_CalcularSemanaISO;
GO

CREATE FUNCTION dbo.fn_CalcularSemanaISO(@Data DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT
        @Data AS Data,
        DATEADD(DAY, -(DATEPART(WEEKDAY, @Data) + 5) % 7, @Data) AS InicioDaSemanaISO,
        DATEADD(DAY, 6, DATEADD(DAY, -(DATEPART(WEEKDAY, @Data) + 5) % 7, @Data)) AS FimDaSemanaISO,
        CASE
            -- Se a primeira quinta-feira do ano é depois do dia 1, então as primeiras semanas pertencem ao ano anterior
            WHEN DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 1)) IN (5, 6, 7) 
                AND DATEPART(DAYOFYEAR, @Data) <= 8 - DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 1)) 
            THEN YEAR(DATEADD(DAY, -7, @Data))
            
            -- Se a última semana do ano não possui quinta-feira, então pertence ao próximo ano
            WHEN DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 1)) IN (2, 3, 4) 
                AND DATEPART(DAYOFYEAR, @Data) >= 367 - DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 1)) 
            THEN YEAR(DATEADD(DAY, 7, @Data))
            
            ELSE YEAR(@Data)
        END AS AnoISO,
        CASE
            -- Se a primeira quinta-feira do ano é depois do dia 1, então as primeiras semanas pertencem ao ano anterior
            WHEN DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 1)) IN (5, 6, 7) 
                AND DATEPART(DAYOFYEAR, @Data) <= 8 - DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 1)) 
            THEN 
                DATEPART(WEEK, DATEADD(DAY, -(DATEPART(DAYOFYEAR, @Data) - 1), @Data)) + 
                DATEPART(WEEK, DATEFROMPARTS(YEAR(DATEADD(DAY, -7, @Data)), 12, 31)) - 1
            
            -- Se a última semana do ano não possui quinta-feira, então pertence ao próximo ano
            WHEN DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 1)) IN (2, 3, 4) 
                AND DATEPART(DAYOFYEAR, @Data) >= 367 - DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 1)) 
            THEN 1
            
            ELSE 
                -- Determina o dia da primeira semana ISO do ano (pode ser no ano anterior)
                DATEDIFF(
                    WEEK,
                    DATEADD(
                        DAY,
                        1 - DATEPART(WEEKDAY, DATEFROMPARTS(YEAR(@Data), 1, 4)), -- 4 de janeiro sempre está na primeira semana ISO
                        DATEFROMPARTS(YEAR(@Data), 1, 4)
                    ),
                    DATEADD(DAY, -(DATEPART(WEEKDAY, @Data) + 5) % 7, @Data)
                ) + 1
        END AS SemanaISO
);
GO

-- 3. Função auxiliar para verificar se a data é dia útil
IF OBJECT_ID('dbo.fn_IsDiaUtil') IS NOT NULL
    DROP FUNCTION dbo.fn_IsDiaUtil;
GO

CREATE FUNCTION dbo.fn_IsDiaUtil(@Data DATE, @Feriado BIT)
RETURNS BIT
AS
BEGIN
    DECLARE @DiaUtil BIT = 1;
    
    -- Se for fim de semana (sábado=7 ou domingo=1)
    IF DATEPART(WEEKDAY, @Data) IN (1, 7)
        SET @DiaUtil = 0;
    
    -- Se for feriado
    IF @Feriado = 1
        SET @DiaUtil = 0;
        
    RETURN @DiaUtil;
END;
GO

-- 4. Função para obter texto localizado base na cultura selecionada
IF OBJECT_ID('dbo.fn_ObterTextoLocalizado') IS NOT NULL
    DROP FUNCTION dbo.fn_ObterTextoLocalizado;
GO

CREATE FUNCTION dbo.fn_ObterTextoLocalizado(
    @TextKey NVARCHAR(50),
    @CultureInfo NVARCHAR(10)
)
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @Result NVARCHAR(200);
    
    SET @Result = CASE @TextKey
        -- Textos gerais
        WHEN 'TextoAtual' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Atual'
                WHEN 'en-US' THEN N'Current'
                WHEN 'es-ES' THEN N'Actual'
                ELSE N'Atual' -- Padrão
            END
        WHEN 'PrefixoTrimestre' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'T'
                WHEN 'en-US' THEN N'Q'
                WHEN 'es-ES' THEN N'T'
                ELSE N'T' -- Padrão
            END
        WHEN 'PrefixoSemana' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'S'
                WHEN 'en-US' THEN N'W'
                WHEN 'es-ES' THEN N'S'
                ELSE N'S' -- Padrão
            END
        WHEN 'PrefixoSemestre' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'S'
                WHEN 'en-US' THEN N'H'
                WHEN 'es-ES' THEN N'S'
                ELSE N'S' -- Padrão
            END
        WHEN 'PrefixoBimestre' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'B'
                WHEN 'en-US' THEN N'B'
                WHEN 'es-ES' THEN N'B'
                ELSE N'B' -- Padrão
            END
        WHEN 'PrefixoQuinzena' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Q'
                WHEN 'en-US' THEN N'F'
                WHEN 'es-ES' THEN N'Q'
                ELSE N'Q' -- Padrão
            END
        -- Estações do Ano
        WHEN 'TextoVerao' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Verão'
                WHEN 'en-US' THEN N'Summer'
                WHEN 'es-ES' THEN N'Verano'
                ELSE N'Verão' -- Padrão
            END
        WHEN 'TextoPrimavera' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Primavera'
                WHEN 'en-US' THEN N'Spring'
                WHEN 'es-ES' THEN N'Primavera'
                ELSE N'Primavera' -- Padrão
            END
        WHEN 'TextoOutono' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Outono'
                WHEN 'en-US' THEN N'Autumn'
                WHEN 'es-ES' THEN N'Otoño'
                ELSE N'Outono' -- Padrão
            END
        WHEN 'TextoInverno' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Inverno'
                WHEN 'en-US' THEN N'Winter'
                WHEN 'es-ES' THEN N'Invierno'
                ELSE N'Inverno' -- Padrão
            END
        -- Dias úteis
        WHEN 'TextoDiaUtil' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Dia Útil'
                WHEN 'en-US' THEN N'Working Day'
                WHEN 'es-ES' THEN N'Día Hábil'
                ELSE N'Dia Útil' -- Padrão
            END
        WHEN 'TextoDiaNaoUtil' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Dia Não Útil'
                WHEN 'en-US' THEN N'Non-Working Day'
                WHEN 'es-ES' THEN N'Día No Hábil'
                ELSE N'Dia Não Útil' -- Padrão
            END
        WHEN 'PrefixoTrimestreFiscal' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'TE'
                WHEN 'en-US' THEN N'FQ'
                WHEN 'es-ES' THEN N'TE'
                ELSE N'EF' -- Padrão
            END
        WHEN 'PrefixoAnoFiscal' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'EF'
                WHEN 'en-US' THEN N'FY'
                WHEN 'es-ES' THEN N'EF'
                ELSE N'EF' -- Padrão
            END
        WHEN 'TextoSemanaUtil' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Semana Útil'
                WHEN 'en-US' THEN N'Work Week'
                WHEN 'es-ES' THEN N'Semana Laboral'
                ELSE N'Semana Útil' -- Padrão
            END
		WHEN 'TextoFinalDeSemana' THEN
			CASE @CultureInfo
				WHEN 'pt-BR' THEN N'Final de Semana'
				WHEN 'en-US' THEN N'Weekend'
				WHEN 'es-ES' THEN N'Fin de Semana'
				ELSE N'Final de Semana' -- Padrão
			END
		WHEN 'TextoFeriado' THEN
			CASE @CultureInfo
				WHEN 'pt-BR' THEN N'Feriado'
				WHEN 'en-US' THEN N'Holiday'
				WHEN 'es-ES' THEN N'Día Festivo'
				ELSE N'Feriado' -- Padrão
			END
			
        -- Feriados Fixos
        WHEN 'FeriadoConfraternizacaoUniversal' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Confraternização Universal'
                WHEN 'en-US' THEN N'New Year''s Day'
                WHEN 'es-ES' THEN N'Año Nuevo'
                ELSE N'Confraternização Universal' -- Padrão
            END
        WHEN 'FeriadoAniversarioCidade' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Aniversário da Cidade'
                WHEN 'en-US' THEN N'City Anniversary'
                WHEN 'es-ES' THEN N'Aniversario de la Ciudad'
                ELSE N'Aniversário da Cidade' -- Padrão
            END
        WHEN 'FeriadoTiradentes' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Tiradentes'
                WHEN 'en-US' THEN N'Tiradentes Day'
                WHEN 'es-ES' THEN N'Día de Tiradentes'
                ELSE N'Tiradentes' -- Padrão
            END
        WHEN 'FeriadoDiaTrabalho' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Dia do Trabalhador'
                WHEN 'en-US' THEN N'Labor Day'
                WHEN 'es-ES' THEN N'Día del Trabajo'
                ELSE N'Dia do Trabalhador' -- Padrão
            END
        WHEN 'FeriadoRevolucaoConstitucionalista' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Revolução Constitucionalista'
                WHEN 'en-US' THEN N'Constitutional Revolution'
                WHEN 'es-ES' THEN N'Revolución Constitucionalista'
                ELSE N'Revolução Constitucionalista' -- Padrão
            END
        WHEN 'FeriadoIndependencia' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Independência do Brasil'
                WHEN 'en-US' THEN N'Independence Day'
                WHEN 'es-ES' THEN N'Día de la Independencia'
                ELSE N'Independência do Brasil' -- Padrão
            END
        WHEN 'FeriadoNSAparecida' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'N. Srª Aparecida'
                WHEN 'en-US' THEN N'Our Lady of Aparecida'
                WHEN 'es-ES' THEN N'Nuestra Señora Aparecida'
                ELSE N'N. Srª Aparecida' -- Padrão
            END
        WHEN 'FeriadoFinados' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Finados'
                WHEN 'en-US' THEN N'All Souls'' Day'
                WHEN 'es-ES' THEN N'Día de los Muertos'
                ELSE N'Finados' -- Padrão
            END
        WHEN 'FeriadoProclamacaoRepublica' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Proclamação da República'
                WHEN 'en-US' THEN N'Republic Proclamation Day'
                WHEN 'es-ES' THEN N'Proclamación de la República'
                ELSE N'Proclamação da República' -- Padrão
            END
        WHEN 'FeriadoConscienciaNegra' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Consciência Negra'
                WHEN 'en-US' THEN N'Black Awareness Day'
                WHEN 'es-ES' THEN N'Día de la Conciencia Negra'
                ELSE N'Consciência Negra' -- Padrão
            END
        WHEN 'FeriadoVesperaNatal' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Véspera de Natal'
                WHEN 'en-US' THEN N'Christmas Eve'
                WHEN 'es-ES' THEN N'Nochebuena'
                ELSE N'Véspera de Natal' -- Padrão
            END
        WHEN 'FeriadoNatal' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Natal'
                WHEN 'en-US' THEN N'Christmas Day'
                WHEN 'es-ES' THEN N'Navidad'
                ELSE N'Natal' -- Padrão
            END
        WHEN 'FeriadoVesperaAnoNovo' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Véspera de Ano Novo'
                WHEN 'en-US' THEN N'New Year''s Eve'
                WHEN 'es-ES' THEN N'Nochevieja'
                ELSE N'Véspera de Ano Novo' -- Padrão
            END
            
        -- Feriados Móveis
        WHEN 'FeriadoSextaFeiraSanta' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Sexta-Feira Santa'
                WHEN 'en-US' THEN N'Good Friday'
                WHEN 'es-ES' THEN N'Viernes Santo'
                ELSE N'Sexta-Feira Santa' -- Padrão
            END
        WHEN 'FeriadoPascoa' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Páscoa'
                WHEN 'en-US' THEN N'Easter Sunday'
                WHEN 'es-ES' THEN N'Domingo de Pascua'
                ELSE N'Páscoa' -- Padrão
            END
        WHEN 'FeriadoCorpusChristi' THEN
            CASE @CultureInfo
                WHEN 'pt-BR' THEN N'Corpus Christi'
                WHEN 'en-US' THEN N'Corpus Christi'
                WHEN 'es-ES' THEN N'Corpus Christi'
                ELSE N'Corpus Christi' -- Padrão
            END
                
        ELSE N'Texto não encontrado'
    END;
    
    RETURN @Result;
END;
GO

-- 5 Criar função auxiliar para capitalizar texto (primeira letra de cada palavra em maiúscula)
IF OBJECT_ID('dbo.fn_CapitalizarTexto') IS NOT NULL
    DROP FUNCTION dbo.fn_CapitalizarTexto;
GO

CREATE FUNCTION dbo.fn_CapitalizarTexto(@Texto NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    IF @Texto IS NULL OR LEN(@Texto) = 0
        RETURN @Texto;
    
    DECLARE @Resultado NVARCHAR(MAX) = '';
    DECLARE @Posicao INT = 1;
    DECLARE @Char NCHAR(1);
    DECLARE @ProximoCharMaiusculo BIT = 1; -- Primeira letra sempre maiúscula
    
    WHILE @Posicao <= LEN(@Texto)
    BEGIN
        SET @Char = SUBSTRING(@Texto, @Posicao, 1);
        
        -- Se encontrar espaço ou hífen, a próxima letra deve ser maiúscula
        IF @Char = N' ' OR @Char = N'-'
        BEGIN
            SET @Resultado = @Resultado + @Char;
            SET @ProximoCharMaiusculo = 1;
        END
        ELSE
        BEGIN
            IF @ProximoCharMaiusculo = 1
                SET @Resultado = @Resultado + UPPER(@Char);
            ELSE
                SET @Resultado = @Resultado + LOWER(@Char);
                
            SET @ProximoCharMaiusculo = 0;
        END
        
        SET @Posicao = @Posicao + 1;
    END
    
    RETURN @Resultado;
END;
GO

-- 6. Função para calcular as datas de início e fim da semana útil
IF OBJECT_ID('dbo.fn_CalcularSemanaUtil') IS NOT NULL
    DROP FUNCTION dbo.fn_CalcularSemanaUtil;
GO

CREATE FUNCTION dbo.fn_CalcularSemanaUtil(
    @Data DATE,                -- Data de referência para o cálculo
    @DiaSemanaUtilInicio INT,  -- Dia de início da semana útil (1=domingo, 2=segunda, ..., 7=sábado)
    @DiaSemanaUtilFim INT,     -- Dia de fim da semana útil (1=domingo, 2=segunda, ..., 7=sábado)
    @UsarSemanaFutura BIT = 0  -- 0 = usar semana atual/anterior, 1 = usar próxima semana
)
RETURNS TABLE
AS
RETURN
(
    -- Validação básica dos parâmetros de entrada
    WITH ValidacaoParametros AS (
        SELECT
            @Data AS Data,
            -- Se os parâmetros estão fora do intervalo válido, usar valores padrão (Segunda a Sexta)
            CASE WHEN @DiaSemanaUtilInicio < 1 OR @DiaSemanaUtilInicio > 7 THEN 2 ELSE @DiaSemanaUtilInicio END AS DiaSemanaUtilInicio,
            CASE WHEN @DiaSemanaUtilFim < 1 OR @DiaSemanaUtilFim > 7 THEN 6 ELSE @DiaSemanaUtilFim END AS DiaSemanaUtilFim,
            @UsarSemanaFutura AS UsarSemanaFutura
    ),
    InicioSemanaUtil AS (
        SELECT
            v.Data,
            v.DiaSemanaUtilInicio,
            v.DiaSemanaUtilFim,
            v.UsarSemanaFutura,
            -- Calcular o início da semana útil
            DATEADD(DAY, 
                (
                    -- Calcular o ajuste de dias necessário para chegar ao dia de início da semana útil
                    CASE 
                        -- Se o dia atual é o mesmo que o dia de início, e não queremos a semana futura
                        WHEN DATEPART(WEEKDAY, v.Data) = v.DiaSemanaUtilInicio AND v.UsarSemanaFutura = 0
                            THEN 0
                        
                        -- Se o dia atual é após o dia de início, e não queremos a semana futura
                        -- Voltamos para o último dia de início da semana útil
                        WHEN DATEPART(WEEKDAY, v.Data) > v.DiaSemanaUtilInicio AND v.UsarSemanaFutura = 0
                            THEN -1 * (DATEPART(WEEKDAY, v.Data) - v.DiaSemanaUtilInicio)
                        
                        -- Se o dia atual é antes do dia de início, ou queremos a semana futura
                        ELSE 
                            CASE 
                                -- Se o dia atual é antes do dia de início, e não queremos a semana futura
                                -- Voltamos para a semana anterior para encontrar o dia de início
                                WHEN DATEPART(WEEKDAY, v.Data) < v.DiaSemanaUtilInicio AND v.UsarSemanaFutura = 0
                                    THEN -1 * (DATEPART(WEEKDAY, v.Data) + 7 - v.DiaSemanaUtilInicio)
                                
                                -- Se queremos a semana futura ou o dia atual está após o dia de fim
                                -- Avançamos para a próxima ocorrência do dia de início
                                ELSE 
                                    -- Calcula dias para o próximo dia de início da semana
                                    (7 - DATEPART(WEEKDAY, v.Data) + v.DiaSemanaUtilInicio) % 7
                                    -- Ajuste para evitar adicionar 0 dias quando deveria avançar uma semana completa
                                    + CASE WHEN (7 - DATEPART(WEEKDAY, v.Data) + v.DiaSemanaUtilInicio) % 7 = 0 THEN 7 ELSE 0 END
                            END
                    END
                ),
                v.Data
            ) AS SemanaUtilInicio
        FROM ValidacaoParametros v
    )
    -- Resultado final com início e fim da semana útil
    SELECT
        i.Data,
        i.SemanaUtilInicio,
        -- Calcular o fim da semana útil, baseado no início calculado acima
        DATEADD(DAY,
            (
                -- Dias para adicionar ao início para chegar ao fim da semana útil
                CASE
                    -- Se o dia de início é o mesmo que o de fim, a semana útil é apenas um dia
                    WHEN i.DiaSemanaUtilInicio = i.DiaSemanaUtilFim THEN 0
                    
                    -- Se o dia de fim é após o dia de início na mesma semana
                    WHEN i.DiaSemanaUtilFim > i.DiaSemanaUtilInicio
                        THEN i.DiaSemanaUtilFim - i.DiaSemanaUtilInicio
                    
                    -- Se o dia de fim é antes do dia de início, então a semana útil cruza a semana
                    -- Exemplo: quinta-feira (DiaSemanaUtilInicio=5) até terça-feira (DiaSemanaUtilFim=3)
                    ELSE 7 - (i.DiaSemanaUtilInicio - i.DiaSemanaUtilFim)
                END
            ),
            i.SemanaUtilInicio
        ) AS SemanaUtilFim,
        
        -- Verificar se o próprio dia é útil (usado na nova versão para aplicar a correção)
        CASE
            WHEN DATEPART(WEEKDAY, i.Data) BETWEEN i.DiaSemanaUtilInicio AND i.DiaSemanaUtilFim THEN 1
            WHEN i.DiaSemanaUtilInicio > i.DiaSemanaUtilFim  -- Semana cruza final de semana
                AND (DATEPART(WEEKDAY, i.Data) >= i.DiaSemanaUtilInicio 
                     OR DATEPART(WEEKDAY, i.Data) <= i.DiaSemanaUtilFim) THEN 1
            ELSE 0
        END AS EhDiaDentroDaSemanaUtil
    FROM InicioSemanaUtil i
);
GO

-- Confirmação da criação das funções
PRINT '✓ Função fn_CalcularPascoa criada com sucesso!'
PRINT '✓ Função fn_CalcularSemanaISO criada com sucesso!'
PRINT '✓ Função fn_IsDiaUtil criada com sucesso!'
PRINT '✓ Função fn_ObterTextoLocalizado criada com sucesso!'
PRINT '✓ Função fn_CapitalizarTexto criada com sucesso!'
PRINT '✓ Função fn_CalcularSemanaUtil criada com sucesso!'
PRINT ''
PRINT 'Todas as funções auxiliares para a tabela calendário foram criadas com sucesso.'
PRINT 'Para criar a tabela TraducaoColunas, execute o script 02_CriarTabelaTraducaoColunas.sql'