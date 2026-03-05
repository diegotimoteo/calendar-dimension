--==============================================================================================
-- Script para criar e popular tabela de traduções de colunas
-- Versão 1.0
-- Autor: Diego Timóteo
-- Deve ser executado após 01_CriarFuncoesCalendario.sql e antes de 03_CriarTabelaFeriados.sql
--==============================================================================================

-- Configurações iniciais
SET NOCOUNT ON;
GO

-- Verificar e criar o schema DW se não existir
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'DW')
BEGIN
    EXEC('CREATE SCHEMA DW')
END
GO

-- Criar tabela para armazenar as traduções das colunas
IF OBJECT_ID('DW.TraducaoColunas') IS NOT NULL
    DROP TABLE DW.TraducaoColunas;

CREATE TABLE DW.TraducaoColunas (
    IdiomaOrigem NVARCHAR(10) NOT NULL,
    NomeOriginal NVARCHAR(128) NOT NULL,
    IdiomaDestino NVARCHAR(10) NOT NULL,
    NomeTraduzido NVARCHAR(128) NOT NULL,
    PRIMARY KEY (IdiomaOrigem, NomeOriginal, IdiomaDestino)
);
GO

-- Popular a tabela com traduções para os idiomas suportados
INSERT INTO DW.TraducaoColunas VALUES
-- Para manter o código organizado, dividimos as traduções por seções

-- Traduções de pt-BR para en-US (Português para Inglês)
-- Colunas de Dados
('pt-BR', 'Data', 'en-US', 'Date'),
('pt-BR', 'DataIndice', 'en-US', 'DateIndex'),
('pt-BR', 'DiasParaHoje', 'en-US', 'DaysToToday'),
('pt-BR', 'DataAtual', 'en-US', 'CurrentDate'),

-- Ano
('pt-BR', 'Ano', 'en-US', 'Year'),
('pt-BR', 'AnoInicio', 'en-US', 'YearStart'),
('pt-BR', 'AnoFim', 'en-US', 'YearEnd'),
('pt-BR', 'AnoIndice', 'en-US', 'YearIndex'),
('pt-BR', 'AnoDecrescenteNome', 'en-US', 'YearDescendingName'),
('pt-BR', 'AnoDecrescenteNumero', 'en-US', 'YearDescendingNumber'),
('pt-BR', 'AnosParaHoje', 'en-US', 'YearsToToday'),
('pt-BR', 'AnoAtual', 'en-US', 'CurrentYear'),

-- Dia
('pt-BR', 'DiaDoMes', 'en-US', 'DayOfMonth'),
('pt-BR', 'DiaDoAno', 'en-US', 'DayOfYear'),
('pt-BR', 'DiaDaSemanaNumero', 'en-US', 'DayOfWeekNumber'),
('pt-BR', 'DiaDaSemanaNome', 'en-US', 'DayOfWeekName'),
('pt-BR', 'DiaDaSemanaNomeAbreviado', 'en-US', 'DayOfWeekNameShort'),
('pt-BR', 'DiaDaSemanaNomeIniciais', 'en-US', 'DayOfWeekInitials'),

-- Mês
('pt-BR', 'MesNumero', 'en-US', 'MonthNumber'),
('pt-BR', 'MesNome', 'en-US', 'MonthName'),
('pt-BR', 'MesNomeAbreviado', 'en-US', 'MonthNameShort'),
('pt-BR', 'MesNomeIniciais', 'en-US', 'MonthInitials'),
('pt-BR', 'MesAnoNome', 'en-US', 'MonthYearName'),
('pt-BR', 'MesAnoNumero', 'en-US', 'MonthYearNumber'),
('pt-BR', 'MesDiaNumero', 'en-US', 'MonthDayNumber'),
('pt-BR', 'MesDiaNome', 'en-US', 'MonthDayName'),
('pt-BR', 'MesInicio', 'en-US', 'MonthStart'),
('pt-BR', 'MesFim', 'en-US', 'MonthEnd'),
('pt-BR', 'MesIndice', 'en-US', 'MonthIndex'),
('pt-BR', 'MesesParaHoje', 'en-US', 'MonthsToToday'),
('pt-BR', 'MesAtualNome', 'en-US', 'CurrentMonthName'),
('pt-BR', 'MesAtualNomeAbreviado', 'en-US', 'CurrentMonthNameShort'),
('pt-BR', 'MesAnoAtualNome', 'en-US', 'CurrentMonthYearName'),

-- Trimestre
('pt-BR', 'TrimestreNumero', 'en-US', 'QuarterNumber'),
('pt-BR', 'TrimestreNome', 'en-US', 'QuarterName'),
('pt-BR', 'TrimestreAnoNome', 'en-US', 'QuarterYearName'),
('pt-BR', 'TrimestreAnoNumero', 'en-US', 'QuarterYearNumber'),
('pt-BR', 'TrimestreInicio', 'en-US', 'QuarterStart'),
('pt-BR', 'TrimestreFim', 'en-US', 'QuarterEnd'),
('pt-BR', 'TrimestreIndice', 'en-US', 'QuarterIndex'),
('pt-BR', 'TrimestresParaHoje', 'en-US', 'QuartersToToday'),
('pt-BR', 'TrimestreAtual', 'en-US', 'CurrentQuarter'),
('pt-BR', 'TrimestreAnoAtual', 'en-US', 'CurrentQuarterYear'),
('pt-BR', 'MesDoTrimestreNumero', 'en-US', 'MonthOfQuarterNumber'),

-- Semana
('pt-BR', 'SemanaDoAnoNumeroISO', 'en-US', 'WeekOfYearISO'),
('pt-BR', 'AnoISO', 'en-US', 'YearISO'),
('pt-BR', 'SemanaAnoNumeroISO', 'en-US', 'WeekYearNumberISO'),
('pt-BR', 'SemanaAnoNomeISO', 'en-US', 'WeekYearNameISO'),
('pt-BR', 'SemanaInicioISO', 'en-US', 'WeekStartISO'),
('pt-BR', 'SemanaFimISO', 'en-US', 'WeekEndISO'),
('pt-BR', 'SemanaIndiceISO', 'en-US', 'WeekIndexISO'),
('pt-BR', 'SemanasParaHojeISO', 'en-US', 'WeeksToTodayISO'),
('pt-BR', 'SemanaAtualISO', 'en-US', 'CurrentWeekISO'),
('pt-BR', 'SemanaPeriodoNome', 'en-US', 'WeekPeriodName'),
('pt-BR', 'SemanaDoMesNumero', 'en-US', 'WeekOfMonthNumber'),

-- Semana Útil
('pt-BR', 'SemanaUtilInicio', 'en-US', 'UsefulWeekStart'),
('pt-BR', 'SemanaUtilFim', 'en-US', 'UsefulWeekEnd'),
('pt-BR', 'SemanaUtilPeriodoNome', 'en-US', 'UsefulWeekPeriodName'),
('pt-BR', 'SemanaUtilIndice', 'en-US', 'UsefulWeekIndex'),

-- Semestre
('pt-BR', 'SemestreNumero', 'en-US', 'NumberHalfYear'),
('pt-BR', 'SemestreAnoNome', 'en-US', 'HalfYearName'),
('pt-BR', 'SemestreAnoNumero', 'en-US', 'HalfYearNumber'),
('pt-BR', 'SemestreIndice', 'en-US', 'HalfYearIndex'),
('pt-BR', 'SemestresParaHoje', 'en-US', 'HalfYearsToToday'),
('pt-BR', 'SemestreAtual', 'en-US', 'CurrentHalfYear'),

-- Bimestre
('pt-BR', 'BimestreNumero', 'en-US', 'BimonthNumber'),
('pt-BR', 'BimestreAnoNome', 'en-US', 'BimonthYearName'),
('pt-BR', 'BimestreAnoNumero', 'en-US', 'BimonthYearNumber'),
('pt-BR', 'BimestreIndice', 'en-US', 'BimonthIndex'),
('pt-BR', 'BimestresParaHoje', 'en-US', 'BimonthsToToday'),
('pt-BR', 'BimestreAtual', 'en-US', 'CurrentBimonth'),

-- Quinzena
('pt-BR', 'QuinzenaDoMesNumero', 'en-US', 'FortnightOfMonthNumber'),
('pt-BR', 'QuinzenaMesNumero', 'en-US', 'FortnightMonthNumber'),
('pt-BR', 'QuinzenaMesNome', 'en-US', 'FortnightMonthName'),
('pt-BR', 'QuinzenaMesAnoNumero', 'en-US', 'FortnightMonthYearNumber'),
('pt-BR', 'QuinzenaMesAnoNome', 'en-US', 'FortnightMonthYearName'),
('pt-BR', 'QuinzenaIndice', 'en-US', 'FortnightIndex'),
('pt-BR', 'QuinzenasParaHoje', 'en-US', 'FortnightsToToday'),
('pt-BR', 'QuinzenaAtual', 'en-US', 'CurrentFortnight'),

-- Fechamento
('pt-BR', 'DataDeFechamentoRef', 'en-US', 'ClosingDateRef'),
('pt-BR', 'AnoFechamento', 'en-US', 'ClosingYear'),
('pt-BR', 'MesFechamentoNome', 'en-US', 'ClosingMonthName'),
('pt-BR', 'MesFechamentoNomeAbreviado', 'en-US', 'ClosingMonthNameShort'),
('pt-BR', 'MesFechamentoNumero', 'en-US', 'ClosingMonthNumber'),
('pt-BR', 'MesAnoFechamentoNome', 'en-US', 'ClosingMonthYearName'),
('pt-BR', 'MesAnoFechamentoNumero', 'en-US', 'ClosingMonthYearNumber'),

-- Estação
('pt-BR', 'EstacaoNorteNumero', 'en-US', 'SeasonNorthNumber'),
('pt-BR', 'EstacaoNorteNome', 'en-US', 'SeasonNorthName'),
('pt-BR', 'EstacaoSulNumero', 'en-US', 'SeasonSouthNumber'),
('pt-BR', 'EstacaoSulNome', 'en-US', 'SeasonSouthName'),

-- Dias Úteis e Feriados
('pt-BR', 'Feriado', 'en-US', 'Holiday'),
('pt-BR', 'DiaUtilNumero', 'en-US', 'WorkingDayFlag'),
('pt-BR', 'DiaUtilNome', 'en-US', 'WorkingDayName'),

-- Ano Fiscal
('pt-BR', 'AnoFiscalInicialNumero', 'en-US', 'FiscalYearStartNumber'),
('pt-BR', 'AnoFiscalFinalNumero', 'en-US', 'FiscalYearEndNumber'),
('pt-BR', 'AnoFiscal', 'en-US', 'FiscalYear'),
('pt-BR', 'AnoFiscalInicio', 'en-US', 'FiscalYearStart'),
('pt-BR', 'AnoFiscalFim', 'en-US', 'FiscalYearEnd'),
('pt-BR', 'AnoFiscalAtual', 'en-US', 'CurrentFiscalYear'),
('pt-BR', 'AnosFiscaisParaHoje', 'en-US', 'FiscalYearsToToday'),

-- Mês Fiscal
('pt-BR', 'MesFiscalNumero', 'en-US', 'FiscalMonthNumber'),
('pt-BR', 'MesFiscalNome', 'en-US', 'FiscalMonthName'),
('pt-BR', 'MesFiscalNomeAbreviado', 'en-US', 'FiscalMonthNameShort'),
('pt-BR', 'MesFiscalAtual', 'en-US', 'CurrentFiscalMonth'),
('pt-BR', 'MesAnoFiscalNome', 'en-US', 'FiscalMonthYearName'),
('pt-BR', 'MesAnoFiscalNumero', 'en-US', 'FiscalMonthYearNumber'),
('pt-BR', 'MesAnoFiscalAtual', 'en-US', 'CurrentFiscalMonthYear'),
('pt-BR', 'MesesFiscaisParaHoje', 'en-US', 'FiscalMonthsToToday'),

-- Trimestre Fiscal
('pt-BR', 'TrimestreFiscalNumero', 'en-US', 'FiscalQuarterNumber'),
('pt-BR', 'TrimestreFiscalNome', 'en-US', 'FiscalQuarterName'),
('pt-BR', 'MesDoTrimestreFiscalNumero', 'en-US', 'MonthOfFiscalQuarterNumber'),
('pt-BR', 'AnoTrimestreFiscalNome', 'en-US', 'FiscalYearQuarterName'),
('pt-BR', 'AnoTrimestreFiscalNumero', 'en-US', 'FiscalYearQuarterNumber'),
('pt-BR', 'TrimestreFiscalInicio', 'en-US', 'FiscalQuarterStart'),
('pt-BR', 'TrimestreFiscalFim', 'en-US', 'FiscalQuarterEnd'),
('pt-BR', 'TrimestresFiscaisParaHoje', 'en-US', 'FiscalQuartersToToday'),
('pt-BR', 'TrimestreFiscalAtual', 'en-US', 'CurrentFiscalQuarter'),
('pt-BR', 'DiaDoTrimestreFiscal', 'en-US', 'DayOfFiscalQuarter'),

-- Traduções de pt-BR para es-ES (Português para Espanhol)
-- Colunas de Dados
('pt-BR', 'Data', 'es-ES', 'Fecha'),
('pt-BR', 'DataIndice', 'es-ES', 'IndiceFecha'),
('pt-BR', 'DiasParaHoje', 'es-ES', 'DiasHastaHoy'),
('pt-BR', 'DataAtual', 'es-ES', 'FechaActual'),

-- Ano
('pt-BR', 'Ano', 'es-ES', 'Año'),
('pt-BR', 'AnoInicio', 'es-ES', 'InicioAño'),
('pt-BR', 'AnoFim', 'es-ES', 'FinAño'),
('pt-BR', 'AnoIndice', 'es-ES', 'IndiceAño'),
('pt-BR', 'AnoDecrescenteNome', 'es-ES', 'NombreAñoDescendente'),
('pt-BR', 'AnoDecrescenteNumero', 'es-ES', 'NumeroAñoDescendente'),
('pt-BR', 'AnosParaHoje', 'es-ES', 'AñosHastaHoy'),
('pt-BR', 'AnoAtual', 'es-ES', 'AñoActual'),

-- Dia
('pt-BR', 'DiaDoMes', 'es-ES', 'DiaDeMes'),
('pt-BR', 'DiaDoAno', 'es-ES', 'DiaDeAño'),
('pt-BR', 'DiaDaSemanaNumero', 'es-ES', 'NumeroDiaSemana'),
('pt-BR', 'DiaDaSemanaNome', 'es-ES', 'NombreDiaSemana'),
('pt-BR', 'DiaDaSemanaNomeAbreviado', 'es-ES', 'NombreDiaSemanaCorto'),
('pt-BR', 'DiaDaSemanaNomeIniciais', 'es-ES', 'InicialesDiaSemana'),

-- Mês
('pt-BR', 'MesNumero', 'es-ES', 'NumeroMes'),
('pt-BR', 'MesNome', 'es-ES', 'NombreMes'),
('pt-BR', 'MesNomeAbreviado', 'es-ES', 'NombreMesCorto'),
('pt-BR', 'MesNomeIniciais', 'es-ES', 'InicialesMes'),
('pt-BR', 'MesAnoNome', 'es-ES', 'NombreMesAño'),
('pt-BR', 'MesAnoNumero', 'es-ES', 'NumeroMesAño'),
('pt-BR', 'MesDiaNumero', 'es-ES', 'NumeroMesDia'),
('pt-BR', 'MesDiaNome', 'es-ES', 'NombreMesDia'),
('pt-BR', 'MesInicio', 'es-ES', 'InicioMes'),
('pt-BR', 'MesFim', 'es-ES', 'FinMes'),
('pt-BR', 'MesIndice', 'es-ES', 'IndiceMes'),
('pt-BR', 'MesesParaHoje', 'es-ES', 'MesesHastaHoy'),
('pt-BR', 'MesAtualNome', 'es-ES', 'NombreMesActual'),
('pt-BR', 'MesAtualNomeAbreviado', 'es-ES', 'NombreMesActualCorto'),
('pt-BR', 'MesAnoAtualNome', 'es-ES', 'NombreMesAñoActual'),

-- Trimestre
('pt-BR', 'TrimestreNumero', 'es-ES', 'NumeroTrimestre'),
('pt-BR', 'TrimestreNome', 'es-ES', 'NombreTrimestre'),
('pt-BR', 'TrimestreAnoNome', 'es-ES', 'NombreTrimestreAño'),
('pt-BR', 'TrimestreAnoNumero', 'es-ES', 'NumeroTrimestreAño'),
('pt-BR', 'TrimestreInicio', 'es-ES', 'InicioTrimestre'),
('pt-BR', 'TrimestreFim', 'es-ES', 'FinTrimestre'),
('pt-BR', 'TrimestreIndice', 'es-ES', 'IndiceTrimestre'),
('pt-BR', 'TrimestresParaHoje', 'es-ES', 'TrimestresHastaHoy'),
('pt-BR', 'TrimestreAtual', 'es-ES', 'TrimestreActual'),
('pt-BR', 'TrimestreAnoAtual', 'es-ES', 'TrimestreAñoActual'),
('pt-BR', 'MesDoTrimestreNumero', 'es-ES', 'NumeroMesTrimestre'),

-- Semana
('pt-BR', 'SemanaDoAnoNumeroISO', 'es-ES', 'NumeroSemanaAñoISO'),
('pt-BR', 'AnoISO', 'es-ES', 'AñoISO'),
('pt-BR', 'SemanaAnoNumeroISO', 'es-ES', 'SemanaAñoNumeroISO'),
('pt-BR', 'SemanaAnoNomeISO', 'es-ES', 'NombreSemanaAñoISO'),
('pt-BR', 'SemanaInicioISO', 'es-ES', 'InicioSemanaISO'),
('pt-BR', 'SemanaFimISO', 'es-ES', 'FinSemanaISO'),
('pt-BR', 'SemanaIndiceISO', 'es-ES', 'IndiceSemanaISO'),
('pt-BR', 'SemanasParaHojeISO', 'es-ES', 'SemanasHastaHoyISO'),
('pt-BR', 'SemanaAtualISO', 'es-ES', 'SemanaActualISO'),
('pt-BR', 'SemanaPeriodoNome', 'es-ES', 'NombrePeriodoSemana'),
('pt-BR', 'SemanaDoMesNumero', 'es-ES', 'NumeroSemanaMes'),

-- Semana Útil
('pt-BR', 'SemanaUtilInicio', 'es-ES', 'InicioSemanaUtil'),
('pt-BR', 'SemanaUtilFim', 'es-ES', 'FinSemanaUtil'),
('pt-BR', 'SemanaUtilPeriodoNome', 'es-ES', 'NombrePeriodoSemanaUtil'),
('pt-BR', 'SemanaUtilIndice', 'es-ES', 'IndiceSemanaUtil'),

-- Semestre
('pt-BR', 'SemestreNumero', 'es-ES', 'NumeroSemestre'),
('pt-BR', 'SemestreAnoNome', 'es-ES', 'NombreSemestreAño'),
('pt-BR', 'SemestreAnoNumero', 'es-ES', 'NumeroSemestreAño'),
('pt-BR', 'SemestreIndice', 'es-ES', 'IndiceSemestre'),
('pt-BR', 'SemestresParaHoje', 'es-ES', 'SemestresHastaHoy'),
('pt-BR', 'SemestreAtual', 'es-ES', 'SemestreActual'),

-- Bimestre
('pt-BR', 'BimestreNumero', 'es-ES', 'NumeroBimestre'),
('pt-BR', 'BimestreAnoNome', 'es-ES', 'NombreBimestreAño'),
('pt-BR', 'BimestreAnoNumero', 'es-ES', 'NumeroBimestreAño'),
('pt-BR', 'BimestreIndice', 'es-ES', 'IndiceBimestre'),
('pt-BR', 'BimestresParaHoje', 'es-ES', 'BimestresHastaHoy'),
('pt-BR', 'BimestreAtual', 'es-ES', 'BimestreActual'),

-- Quinzena
('pt-BR', 'QuinzenaDoMesNumero', 'es-ES', 'QuincenaMesNumero'),
('pt-BR', 'QuinzenaMesNumero', 'es-ES', 'NumeroQuincenaMes'),
('pt-BR', 'QuinzenaMesNome', 'es-ES', 'NombreQuincenaMes'),
('pt-BR', 'QuinzenaMesAnoNumero', 'es-ES', 'NumeroQuincenaMesAño'),
('pt-BR', 'QuinzenaMesAnoNome', 'es-ES', 'NombreQuincenaMesAño'),
('pt-BR', 'QuinzenaIndice', 'es-ES', 'IndiceQuincena'),
('pt-BR', 'QuinzenasParaHoje', 'es-ES', 'QuincenasHastaHoy'),
('pt-BR', 'QuinzenaAtual', 'es-ES', 'QuincenaActual'),

-- Fechamento
('pt-BR', 'DataDeFechamentoRef', 'es-ES', 'FechaDeCierreRef'),
('pt-BR', 'AnoFechamento', 'es-ES', 'AñoCierre'),
('pt-BR', 'MesFechamentoNome', 'es-ES', 'NombreMesCierre'),
('pt-BR', 'MesFechamentoNomeAbreviado', 'es-ES', 'NombreMesCierreCorto'),
('pt-BR', 'MesFechamentoNumero', 'es-ES', 'NumeroMesCierre'),
('pt-BR', 'MesAnoFechamentoNome', 'es-ES', 'NombreMesAñoCierre'),
('pt-BR', 'MesAnoFechamentoNumero', 'es-ES', 'NumeroMesAñoCierre'),

-- Estação
('pt-BR', 'EstacaoNorteNumero', 'es-ES', 'NumeroEstacionNorte'),
('pt-BR', 'EstacaoNorteNome', 'es-ES', 'NombreEstacionNorte'),
('pt-BR', 'EstacaoSulNumero', 'es-ES', 'NumeroEstacionSur'),
('pt-BR', 'EstacaoSulNome', 'es-ES', 'NombreEstacionSur'),

-- Dias Úteis e Feriados
('pt-BR', 'Feriado', 'es-ES', 'Festivo'),
('pt-BR', 'DiaUtilNumero', 'es-ES', 'IndicadorDiaLaborable'),
('pt-BR', 'DiaUtilNome', 'es-ES', 'NombreDiaLaborable'),

-- Ano Fiscal
('pt-BR', 'AnoFiscalInicialNumero', 'es-ES', 'NumeroAñoFiscalInicial'),
('pt-BR', 'AnoFiscalFinalNumero', 'es-ES', 'NumeroAñoFiscalFinal'),
('pt-BR', 'AnoFiscal', 'es-ES', 'AñoFiscal'),
('pt-BR', 'AnoFiscalInicio', 'es-ES', 'InicioAñoFiscal'),
('pt-BR', 'AnoFiscalFim', 'es-ES', 'FinAñoFiscal'),
('pt-BR', 'AnoFiscalAtual', 'es-ES', 'AñoFiscalActual'),
('pt-BR', 'AnosFiscaisParaHoje', 'es-ES', 'AñosFiscalesHastaHoy'),

-- Mês Fiscal
('pt-BR', 'MesFiscalNumero', 'es-ES', 'NumeroMesFiscal'),
('pt-BR', 'MesFiscalNome', 'es-ES', 'NombreMesFiscal'),
('pt-BR', 'MesFiscalNomeAbreviado', 'es-ES', 'NombreMesFiscalCorto'),
('pt-BR', 'MesFiscalAtual', 'es-ES', 'MesFiscalActual'),
('pt-BR', 'MesAnoFiscalNome', 'es-ES', 'NombreMesAñoFiscal'),
('pt-BR', 'MesAnoFiscalNumero', 'es-ES', 'NumeroMesAñoFiscal'),
('pt-BR', 'MesAnoFiscalAtual', 'es-ES', 'MesAñoFiscalActual'),
('pt-BR', 'MesesFiscaisParaHoje', 'es-ES', 'MesesFiscalesHastaHoy'),

-- Trimestre Fiscal
('pt-BR', 'TrimestreFiscalNumero', 'es-ES', 'NumeroTrimestreFiscal'),
('pt-BR', 'TrimestreFiscalNome', 'es-ES', 'NombreTrimestreFiscal'),
('pt-BR', 'MesDoTrimestreFiscalNumero', 'es-ES', 'NumeroMesTrimestreFiscal'),
('pt-BR', 'AnoTrimestreFiscalNome', 'es-ES', 'NombreAñoTrimestreFiscal'),
('pt-BR', 'AnoTrimestreFiscalNumero', 'es-ES', 'NumeroAñoTrimestreFiscal'),
('pt-BR', 'TrimestreFiscalInicio', 'es-ES', 'InicioTrimestreFiscal'),
('pt-BR', 'TrimestreFiscalFim', 'es-ES', 'FinTrimestreFiscal'),
('pt-BR', 'TrimestresFiscaisParaHoje', 'es-ES', 'TrimestresFiscalesHastaHoy'),
('pt-BR', 'TrimestreFiscalAtual', 'es-ES', 'TrimestreFiscalActual'),
('pt-BR', 'DiaDoTrimestreFiscal', 'es-ES', 'DiaDeTrimestreFiscal');


-- Criar função para obter nome traduzido de uma coluna
IF OBJECT_ID('DW.fn_ObterNomeTraduzido') IS NOT NULL
    DROP FUNCTION DW.fn_ObterNomeTraduzido;
GO

CREATE FUNCTION DW.fn_ObterNomeTraduzido(
    @NomeOriginal NVARCHAR(128),
    @IdiomaOrigem NVARCHAR(10),
    @IdiomaDestino NVARCHAR(10)
)
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @NomeTraduzido NVARCHAR(128);
    
    -- Buscar o nome traduzido
    SELECT @NomeTraduzido = NomeTraduzido
    FROM DW.TraducaoColunas
    WHERE IdiomaOrigem = @IdiomaOrigem
    AND NomeOriginal = @NomeOriginal
    AND IdiomaDestino = @IdiomaDestino;
    
    -- Se não encontrar tradução, retorna o nome original
    IF @NomeTraduzido IS NULL
        SET @NomeTraduzido = @NomeOriginal;
    
    RETURN @NomeTraduzido;
END;
GO

PRINT '✓ Tabela DW.TraducaoColunas criada e populada com sucesso';
PRINT '✓ Função DW.fn_ObterNomeTraduzido criada para consulta de traduções';
PRINT 'Agora execute o script 03_CriarTabelasFeriados.sql para criar as tabelas de Feriados';