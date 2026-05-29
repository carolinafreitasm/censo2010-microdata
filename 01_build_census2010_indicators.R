# =============================================================================
# 01_build_census2010_indicators.R
#
# Versão conceitual em R — equivalente metodológico ao script Stata
# Construção de indicadores municipais de gênero e mercado de trabalho
# a partir dos microdados do Censo Demográfico 2010 — IBGE
#
# -----------------------------------------------------------------------------
# SOBRE ESTE SCRIPT
#
# Este script é uma versão de documentação e reprodutibilidade conceitual.
# Ele replica exatamente a lógica do script Stata, mas usando sintaxe R
# com o pacote tidyverse. O objetivo é permitir que usuários de R
# compreendam e reproduzam a metodologia sem precisar do Stata.
#
# -----------------------------------------------------------------------------
# SOBRE OS DADOS
#
# Os microdados do Censo 2010 foram obtidos via pacote datazoom_social,
# desenvolvido pelo DataZoom/PUC-Rio. O pacote facilita o download e a
# leitura dos microdados sociais brasileiros.
#
# Para obter os microdados antes de rodar este script:
#   1. No Stata, instale o datazoom_social:
#      net install datazoom_social, from("https://raw.githubusercontent.com/datazoompuc/datazoom_social_Stata/master/")
#   2. Baixe os microdados do Censo 2010:
#      datazoom_censo, years(2010) sample(pes) saving("sua/pasta")
#   3. Os arquivos gerados (.dta) podem ser lidos no R com o pacote haven
#
#   Referência: https://github.com/datazoompuc/datazoom_social_Stata
#
# -----------------------------------------------------------------------------
# ATENÇÃO — CAMINHOS LOCAIS
#
# Procure por "AJUSTE_AQUI" neste script e substitua pelo caminho correto
# no seu computador antes de executar.
#
# Os microdados brutos NÃO estão no repositório. Apenas a base municipal
# final (data_processed/censo2010_municipios.csv) está disponível.
#
# -----------------------------------------------------------------------------
# PACOTES NECESSÁRIOS
#
# Este script requer os seguintes pacotes do R:
#   haven   — leitura de arquivos .dta (formato Stata)
#   dplyr   — manipulação de dados (filter, mutate, group_by, summarise)
#   purrr   — iteração funcional (map, walk)
#   readr   — escrita de arquivos CSV
#
# Para instalar todos de uma vez:
#   install.packages(c("haven", "dplyr", "purrr", "readr"))
#
# =============================================================================

library(haven)   # leitura de arquivos .dta do Stata
library(dplyr)   # manipulação de dados com verbos legíveis
library(purrr)   # iteração funcional — substitui loops for em muitos casos
library(readr)   # escrita de arquivos CSV com mais controle


# =============================================================================
# PARTE 1 — CONFIGURAÇÃO DOS CAMINHOS
#
# Defina abaixo os caminhos para os microdados brutos e para a pasta
# onde a base municipal final será salva.
#
# Use barras normais (/) mesmo no Windows — o R aceita este formato.
# Exemplos:
#   Windows: "C:/Users/seu_usuario/dados/censo2010"
#   Mac/Linux: "/Users/seu_usuario/dados/censo2010"
# =============================================================================

# AJUSTE_AQUI — pasta onde estão os arquivos CENSO10_XX_pes.dta
DIR_RAW <- "AJUSTE_AQUI/microdados_censo2010"

# AJUSTE_AQUI — pasta onde a base municipal final será salva
DIR_PROCESSED <- "AJUSTE_AQUI/data_processed"

# Cria a pasta de destino se ela ainda não existir
dir.create(DIR_PROCESSED, showWarnings = FALSE, recursive = TRUE)


# =============================================================================
# PARTE 2 — EMPILHAMENTO DOS ARQUIVOS ESTADUAIS
#
# O datazoom_social gera um arquivo .dta por UF, no padrão:
#   CENSO10_XX_pes.dta (ex: CENSO10_SP_pes.dta para São Paulo)
#
# Estratégia em R:
#   1. Criamos um vetor com as siglas das 27 UFs
#   2. Usamos purrr::map() para ler cada arquivo e criar uma lista de tibbles
#   3. Usamos dplyr::bind_rows() para empilhar tudo em um único data frame
#
# Esta abordagem é equivalente ao use + append do Stata, mas mais eficiente
# em R pois constrói o data frame final de uma vez.
#
# ATENÇÃO: O arquivo resultante é muito grande (vários GB em memória).
# Certifique-se de ter RAM suficiente antes de executar.
# Em computadores com menos de 16GB de RAM, o processo pode falhar.
# =============================================================================

# Vetor com as siglas das 27 UFs
ufs <- c(
  "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO",
  "MA", "MG", "MS", "MT", "PA", "PB", "PE", "PI", "PR",
  "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO"
)

# Lê todos os arquivos e empilha em uma única base
# map() aplica a função de leitura a cada elemento do vetor ufs
# bind_rows() junta todos os data frames da lista em um só
censo_br <- ufs |>
  purrr::map(\(uf) {
    # Constrói o caminho completo do arquivo para esta UF
    arquivo <- file.path(DIR_RAW, paste0("CENSO10_", uf, "_pes.dta"))
    # Lê o arquivo .dta do Stata
    # O haven::read_dta() preserva os labels e atributos do Stata
    haven::read_dta(arquivo)
  }) |>
  dplyr::bind_rows()

# Informa quantas observações foram carregadas
cat("Base nacional carregada:", nrow(censo_br), "observações\n")


# =============================================================================
# PARTE 3 — CRIAÇÃO DAS VARIÁVEIS INDIVIDUAIS
#
# Aqui criamos todas as variáveis binárias (0/1) que serão somadas
# depois na agregação municipal.
#
# Lógica geral:
#   variavel = as.integer(condição_1 & condição_2 & ...)
#   as.integer() converte TRUE/FALSE para 1/0
#
# O operador & exige que todas as condições sejam verdadeiras.
# O resultado é 1 apenas quando o indivíduo atende a todos os critérios.
#
# Variáveis do Censo utilizadas (descrição detalhada no cabeçalho):
#   v0601, v6036, v6400, v6900, v1006, v0640, v6525, v6633, v0010, munic
# =============================================================================

censo <- censo_br |>
  dplyr::mutate(
    
    # -------------------------------------------------------------------------
    # 3.1 Recorte etário e de sexo
    # Foco em adultos com 24 anos ou mais, quando a escolaridade
    # está mais consolidada
    # -------------------------------------------------------------------------
    mulher_24 = as.integer(v0601 == 2 & v6036 >= 24),
    homem_24  = as.integer(v0601 == 1 & v6036 >= 24),
    
    # -------------------------------------------------------------------------
    # 3.2 Recorte por nível de escolaridade
    # Três grupos mutuamente exclusivos para cada sexo:
    #   _sup  = superior completo (v6400 == 4)
    #   _med  = médio completo (v6400 == 3)
    #   _fund = fundamental completo/incompleto ou sem instrução
    #           %in% c(1,2) é equivalente ao inlist() do Stata
    # -------------------------------------------------------------------------
    mulher_sup  = as.integer(mulher_24 == 1 & v6400 == 4),
    mulher_med  = as.integer(mulher_24 == 1 & v6400 == 3),
    mulher_fund = as.integer(mulher_24 == 1 & v6400 %in% c(1, 2)),
    homem_sup   = as.integer(homem_24  == 1 & v6400 == 4),
    homem_med   = as.integer(homem_24  == 1 & v6400 == 3),
    homem_fund  = as.integer(homem_24  == 1 & v6400 %in% c(1, 2)),
    
    # -------------------------------------------------------------------------
    # 3.3 Atividade econômica
    # v6900 == 1 indica economicamente ativo
    # -------------------------------------------------------------------------
    mulher_sup_ativa  = as.integer(mulher_sup  == 1 & v6900 == 1),
    mulher_med_ativa  = as.integer(mulher_med  == 1 & v6900 == 1),
    mulher_fund_ativa = as.integer(mulher_fund == 1 & v6900 == 1),
    mulher_ativa      = as.integer(mulher_24   == 1 & v6900 == 1),
    homem_sup_ativa   = as.integer(homem_sup   == 1 & v6900 == 1),
    homem_med_ativa   = as.integer(homem_med   == 1 & v6900 == 1),
    homem_fund_ativa  = as.integer(homem_fund  == 1 & v6900 == 1),
    homem_ativa       = as.integer(homem_24    == 1 & v6900 == 1),
    
    # -------------------------------------------------------------------------
    # 3.4 Residência rural e urbana
    # v1006 == 2 = rural | v1006 == 1 = urbano
    # Criamos ambas porque o denominador do indicador usa rural + urbano
    # -------------------------------------------------------------------------
    mulher_sup_rural   = as.integer(mulher_sup  == 1 & v1006 == 2),
    mulher_med_rural   = as.integer(mulher_med  == 1 & v1006 == 2),
    mulher_fund_rural  = as.integer(mulher_fund == 1 & v1006 == 2),
    mulher_rural       = as.integer(mulher_24   == 1 & v1006 == 2),
    mulher_sup_urbana  = as.integer(mulher_sup  == 1 & v1006 == 1),
    mulher_med_urbana  = as.integer(mulher_med  == 1 & v1006 == 1),
    mulher_fund_urbana = as.integer(mulher_fund == 1 & v1006 == 1),
    homem_sup_rural    = as.integer(homem_sup   == 1 & v1006 == 2),
    homem_med_rural    = as.integer(homem_med   == 1 & v1006 == 2),
    homem_fund_rural   = as.integer(homem_fund  == 1 & v1006 == 2),
    homem_rural        = as.integer(homem_24    == 1 & v1006 == 2),
    homem_sup_urbana   = as.integer(homem_sup   == 1 & v1006 == 1),
    homem_med_urbana   = as.integer(homem_med   == 1 & v1006 == 1),
    homem_fund_urbana  = as.integer(homem_fund  == 1 & v1006 == 1),
    
    # -------------------------------------------------------------------------
    # 3.5 Estado civil
    # v0640 == 1 = casado/a formalmente
    # -------------------------------------------------------------------------
    mulher_sup_casada  = as.integer(mulher_sup  == 1 & v0640 == 1),
    mulher_med_casada  = as.integer(mulher_med  == 1 & v0640 == 1),
    mulher_fund_casada = as.integer(mulher_fund == 1 & v0640 == 1),
    mulher_casada      = as.integer(mulher_24   == 1 & v0640 == 1),
    homem_sup_casado   = as.integer(homem_sup   == 1 & v0640 == 1),
    homem_med_casado   = as.integer(homem_med   == 1 & v0640 == 1),
    homem_fund_casado  = as.integer(homem_fund  == 1 & v0640 == 1),
    homem_casado       = as.integer(homem_24    == 1 & v0640 == 1),
    
    # -------------------------------------------------------------------------
    # 3.6 Rendimento
    # Duas variáveis por grupo:
    #   _renda: binária — 1 se tem renda positiva (para o denominador)
    #   _valor: valor do rendimento (NA para quem não tem renda positiva)
    # dplyr::if_else() é tipo-seguro: exige que os tipos sejam compatíveis
    # -------------------------------------------------------------------------
    mulher_sup_renda  = as.integer(mulher_sup  == 1 & v6525 > 0),
    mulher_med_renda  = as.integer(mulher_med  == 1 & v6525 > 0),
    mulher_fund_renda = as.integer(mulher_fund == 1 & v6525 > 0),
    mulher_renda      = as.integer(mulher_24   == 1 & v6525 > 0),
    homem_sup_renda   = as.integer(homem_sup   == 1 & v6525 > 0),
    homem_med_renda   = as.integer(homem_med   == 1 & v6525 > 0),
    homem_fund_renda  = as.integer(homem_fund  == 1 & v6525 > 0),
    homem_renda       = as.integer(homem_24    == 1 & v6525 > 0),
    
    renda_mulher_sup_valor  = dplyr::if_else(mulher_sup_renda  == 1, as.numeric(v6525), NA_real_),
    renda_homem_sup_valor   = dplyr::if_else(homem_sup_renda   == 1, as.numeric(v6525), NA_real_),
    renda_mulher_med_valor  = dplyr::if_else(mulher_med_renda  == 1, as.numeric(v6525), NA_real_),
    renda_homem_med_valor   = dplyr::if_else(homem_med_renda   == 1, as.numeric(v6525), NA_real_),
    renda_mulher_fund_valor = dplyr::if_else(mulher_fund_renda == 1, as.numeric(v6525), NA_real_),
    renda_homem_fund_valor  = dplyr::if_else(homem_fund_renda  == 1, as.numeric(v6525), NA_real_),
    renda_mulher_total      = dplyr::if_else(mulher_renda      == 1, as.numeric(v6525), NA_real_),
    renda_homem_total       = dplyr::if_else(homem_renda       == 1, as.numeric(v6525), NA_real_),
    
    # -------------------------------------------------------------------------
    # 3.7 Fecundidade
    # v6633 = número de filhos nascidos vivos (só para mulheres)
    # NA para homens e mulheres fora do grupo
    # -------------------------------------------------------------------------
    filhos_sup  = dplyr::if_else(mulher_sup  == 1, as.numeric(v6633), NA_real_),
    filhos_med  = dplyr::if_else(mulher_med  == 1, as.numeric(v6633), NA_real_),
    filhos_fund = dplyr::if_else(mulher_fund == 1, as.numeric(v6633), NA_real_)
  )


# =============================================================================
# PARTE 4 — AGREGAÇÃO MUNICIPAL COM PESO AMOSTRAL
#
# Equivalente ao collapse do Stata com [pweight = v0010], by(munic)
#
# Em R, a soma ponderada é:
#   sum(variavel * peso, na.rm = TRUE)
#
# O na.rm = TRUE ignora os missings (NA), equivalente ao comportamento
# padrão do Stata com pweight quando há valores missing.
#
# O across() aplica a mesma função a múltiplas colunas de uma vez,
# evitando repetição de código.
#
# A lista de variáveis no across() deve corresponder exatamente às
# variáveis binárias criadas na Parte 3.
# =============================================================================

municipios <- censo |>
  dplyr::group_by(munic) |>
  dplyr::summarise(
    
    # Soma ponderada das variáveis binárias (contagens populacionais)
    across(
      c(mulher_sup, mulher_med, mulher_fund, mulher_24,
        mulher_ativa, mulher_sup_ativa, mulher_med_ativa, mulher_fund_ativa,
        homem_sup, homem_med, homem_fund, homem_24,
        homem_ativa, homem_sup_ativa, homem_med_ativa, homem_fund_ativa,
        mulher_sup_rural, mulher_sup_urbana,
        mulher_med_rural, mulher_med_urbana,
        mulher_fund_rural, mulher_fund_urbana, mulher_rural,
        homem_sup_rural, homem_sup_urbana,
        homem_med_rural, homem_med_urbana,
        homem_fund_rural, homem_fund_urbana, homem_rural,
        mulher_sup_casada, mulher_med_casada, mulher_fund_casada, mulher_casada,
        homem_sup_casado, homem_med_casado, homem_fund_casado, homem_casado,
        mulher_sup_renda, mulher_med_renda, mulher_fund_renda, mulher_renda,
        homem_sup_renda, homem_med_renda, homem_fund_renda, homem_renda),
      # Função aplicada: soma ponderada pelo peso amostral
      \(x) sum(x * v0010, na.rm = TRUE)
    ),
    
    # Soma ponderada dos rendimentos (valores monetários)
    renda_mulher_sup_valor  = sum(renda_mulher_sup_valor  * v0010, na.rm = TRUE),
    renda_homem_sup_valor   = sum(renda_homem_sup_valor   * v0010, na.rm = TRUE),
    renda_mulher_med_valor  = sum(renda_mulher_med_valor  * v0010, na.rm = TRUE),
    renda_homem_med_valor   = sum(renda_homem_med_valor   * v0010, na.rm = TRUE),
    renda_mulher_fund_valor = sum(renda_mulher_fund_valor * v0010, na.rm = TRUE),
    renda_homem_fund_valor  = sum(renda_homem_fund_valor  * v0010, na.rm = TRUE),
    renda_mulher_total      = sum(renda_mulher_total      * v0010, na.rm = TRUE),
    renda_homem_total       = sum(renda_homem_total       * v0010, na.rm = TRUE),
    
    # Soma ponderada dos filhos (fecundidade)
    filhos_sup  = sum(filhos_sup  * v0010, na.rm = TRUE),
    filhos_med  = sum(filhos_med  * v0010, na.rm = TRUE),
    filhos_fund = sum(filhos_fund * v0010, na.rm = TRUE),
    
    .groups = "drop"
  )

cat("Municípios na base final:", nrow(municipios), "\n")


# =============================================================================
# PARTE 5 — CÁLCULO DOS INDICADORES FINAIS
#
# Após a agregação, as variáveis contêm somas ponderadas.
# Calculamos agora os indicadores percentuais e razões.
# =============================================================================

municipios <- municipios |>
  dplyr::mutate(
    
    # -------------------------------------------------------------------------
    # 5.1 Taxa de participação na força de trabalho (%)
    # Numerador: soma ponderada de ativos no grupo
    # Denominador: soma ponderada total no grupo
    # -------------------------------------------------------------------------
    part_mulher_sup  = 100 * (mulher_sup_ativa  / mulher_sup),
    part_mulher_med  = 100 * (mulher_med_ativa  / mulher_med),
    part_mulher_fund = 100 * (mulher_fund_ativa / mulher_fund),
    part_mulher      = 100 * (mulher_ativa      / mulher_24),
    part_homem_sup   = 100 * (homem_sup_ativa   / homem_sup),
    part_homem_med   = 100 * (homem_med_ativa   / homem_med),
    part_homem_fund  = 100 * (homem_fund_ativa  / homem_fund),
    part_homem       = 100 * (homem_ativa       / homem_24),
    
    # -------------------------------------------------------------------------
    # 5.2 Proporção rural (%)
    # Denominador usa rural + urbano para excluir missings de localização
    # -------------------------------------------------------------------------
    mulher_rural_sup   = 100 * (mulher_sup_rural  / (mulher_sup_rural  + mulher_sup_urbana)),
    mulher_rural_medio = 100 * (mulher_med_rural  / (mulher_med_rural  + mulher_med_urbana)),
    mulher_rural_fund  = 100 * (mulher_fund_rural / (mulher_fund_rural + mulher_fund_urbana)),
    mulher_rural_total = 100 * (mulher_rural      / mulher_24),
    homem_rural_sup    = 100 * (homem_sup_rural   / (homem_sup_rural   + homem_sup_urbana)),
    homem_rural_medio  = 100 * (homem_med_rural   / (homem_med_rural   + homem_med_urbana)),
    homem_rural_fund   = 100 * (homem_fund_rural  / (homem_fund_rural  + homem_fund_urbana)),
    homem_rural_total  = 100 * (homem_rural       / homem_24),
    
    # -------------------------------------------------------------------------
    # 5.3 Proporção de casados/as (%)
    # -------------------------------------------------------------------------
    mulheres_casada_sup  = 100 * (mulher_sup_casada  / mulher_sup),
    mulheres_casada_med  = 100 * (mulher_med_casada  / mulher_med),
    mulheres_casada_fund = 100 * (mulher_fund_casada / mulher_fund),
    mulheres_casada      = 100 * (mulher_casada      / mulher_24),
    homens_casado_sup    = 100 * (homem_sup_casado   / homem_sup),
    homens_casado_med    = 100 * (homem_med_casado   / homem_med),
    homens_casado_fund   = 100 * (homem_fund_casado  / homem_fund),
    homens_casado        = 100 * (homem_casado       / homem_24),
    
    # -------------------------------------------------------------------------
    # 5.4 Rendimento médio e razão logarítmica mulher/homem
    #
    # O rendimento médio é a soma dos valores dividida pelo número de
    # pessoas com renda positiva — ambos já ponderados pelo peso amostral.
    #
    # A razão logarítmica ln(M/H) é interpretada como:
    #   Negativo → mulheres recebem menos que homens (situação mais comum)
    #   Zero     → paridade salarial
    #   Positivo → mulheres recebem mais que homens
    #
    # log() em R calcula o logaritmo natural (equivalente ao ln() do Stata)
    # -------------------------------------------------------------------------
    media_renda_mulher_sup  = renda_mulher_sup_valor  / mulher_sup_renda,
    media_renda_homem_sup   = renda_homem_sup_valor   / homem_sup_renda,
    rendM_rendH_sup         = log(media_renda_mulher_sup  / media_renda_homem_sup),
    
    media_renda_mulher_med  = renda_mulher_med_valor  / mulher_med_renda,
    media_renda_homem_med   = renda_homem_med_valor   / homem_med_renda,
    rendM_rendH_med         = log(media_renda_mulher_med  / media_renda_homem_med),
    
    media_renda_mulher_fund = renda_mulher_fund_valor / mulher_fund_renda,
    media_renda_homem_fund  = renda_homem_fund_valor  / homem_fund_renda,
    rendM_rendH_fund        = log(media_renda_mulher_fund / media_renda_homem_fund),
    
    media_renda_mulher      = renda_mulher_total      / mulher_renda,
    media_renda_homem       = renda_homem_total       / homem_renda,
    rendM_rendH             = log(media_renda_mulher  / media_renda_homem),
    
    # -------------------------------------------------------------------------
    # 5.5 Taxa de fecundidade por escolaridade
    # Filhos por mulher — medida de fecundidade acumulada
    # -------------------------------------------------------------------------
    tx_fecund_superior = filhos_sup  / mulher_sup,
    tx_fecund_med      = filhos_med  / mulher_med,
    tx_fecund_fund     = filhos_fund / mulher_fund
  )


# =============================================================================
# PARTE 6 — SALVAMENTO DA BASE MUNICIPAL FINAL
#
# Salva apenas o arquivo de indicadores agregados.
# Os microdados brutos e a base CENSO10_BR nunca devem ser salvos
# na pasta do projeto que será versionada no GitHub.
# =============================================================================

readr::write_csv(
  municipios,
  file.path(DIR_PROCESSED, "censo2010_municipios.csv")
)

cat("Base municipal salva em:", file.path(DIR_PROCESSED, "censo2010_municipios.csv"), "\n")
cat("Municípios:", nrow(municipios), "| Variáveis:", ncol(municipios), "\n")