* ===========================================================================
* 01_build_census2010_indicators.do
*
* Construção de indicadores municipais de gênero e mercado de trabalho
* a partir dos microdados do Censo Demográfico 2010 — IBGE
*
* ---------------------------------------------------------------------------
* SOBRE OS DADOS
*
* Os microdados do Censo 2010 foram obtidos via pacote datazoom_social,
* desenvolvido pelo DataZoom/PUC-Rio. O pacote facilita o download e a
* leitura dos microdados sociais brasileiros diretamente no Stata.
*
* Para baixar os microdados antes de rodar este script:
*   1. Instale o pacote datazoom_social no Stata:
*      net install datazoom_social, from("https://raw.githubusercontent.com/datazoompuc/datazoom_social_Stata/master/")
*   2. Execute o comando de download do Censo 2010:
*      datazoom_censo, years(2010) sample(pes) saving("sua/pasta/local")
*
*   Referência: https://github.com/datazoompuc/datazoom_social_Stata
*
* ---------------------------------------------------------------------------
* ATENÇÃO — CAMINHOS LOCAIS
*
* Este script utiliza caminhos que DEVEM ser ajustados pelo usuário.
* Procure por "AJUSTE AQUI" no script e substitua pelos caminhos
* corretos no seu computador antes de executar.
*
* Os microdados brutos NÃO estão incluídos no repositório.
* Apenas a base municipal final (data_processed/censo2010_municipios.csv)
* está disponível para uso direto.
*
* ---------------------------------------------------------------------------
* ESTRUTURA DO SCRIPT
*
*   Parte 1 — Configuração do diretório de trabalho
*   Parte 2 — Empilhamento dos arquivos estaduais (27 UFs)
*   Parte 3 — Definição da população de análise
*   Parte 4 — Variáveis de atividade econômica
*   Parte 5 — Variáveis de residência rural/urbana
*   Parte 6 — Variáveis de estado civil
*   Parte 7 — Variáveis de rendimento
*   Parte 8 — Variáveis de fecundidade
*   Parte 9 — Agregação municipal com peso amostral
*   Parte 10 — Cálculo dos indicadores finais
*
* ---------------------------------------------------------------------------
* VARIÁVEIS DO CENSO 2010 UTILIZADAS
*
*   v0601  — Sexo (1 = homem, 2 = mulher)
*   v6036  — Idade
*   v6400  — Nível de instrução
*              1 = Sem instrução ou fundamental incompleto
*              2 = Fundamental completo
*              3 = Médio completo
*              4 = Superior completo
*   v6900  — Condição de atividade econômica
*              1 = Economicamente ativo
*              2 = Não economicamente ativo
*   v1006  — Situação do domicílio
*              1 = Urbano
*              2 = Rural
*   v0640  — Estado civil
*              1 = Casado/a
*              2 a 6 = Outras situações
*   v6525  — Rendimento mensal (em reais)
*              Inclui todas as fontes de rendimento
*              Valor 0 = sem rendimento
*   v6633  — Número de filhos nascidos vivos
*              Coletado apenas para mulheres
*   v0010  — Peso amostral
*              Fator de expansão que representa quantas pessoas
*              reais cada entrevistado representa na população
*   munic  — Código do município (7 dígitos, padrão IBGE)
*
* ---------------------------------------------------------------------------
* UNIDADE DE ANÁLISE FINAL: município
* POPULAÇÃO DE REFERÊNCIA: indivíduos com 24 anos ou mais
* AUTORA: Carolina Freitas — UFPR / PUCRS
* ===========================================================================


* ===========================================================================
* PARTE 1 — CONFIGURAÇÃO DO DIRETÓRIO DE TRABALHO
* ===========================================================================

* ---------------------------------------------------------------------------
* AJUSTE AQUI
* Substitua o caminho abaixo pela pasta onde estão os microdados do Censo
* no seu computador. Use barras normais (/) ou barras duplas (\\).
*
* Exemplos:
*   Windows: cd "C:\Users\seu_usuario\dados\censo2010"
*   Mac/Linux: cd "/Users/seu_usuario/dados/censo2010"
* ---------------------------------------------------------------------------

cd "AJUSTE_AQUI/microdados_censo2010"


* ===========================================================================
* PARTE 2 — EMPILHAMENTO DOS ARQUIVOS ESTADUAIS
*
* O datazoom_social gera um arquivo .dta separado para cada Unidade da
* Federação, seguindo o padrão de nomenclatura: CENSO10_XX_pes.dta
* onde XX é a sigla da UF (ex: CENSO10_SP_pes.dta para São Paulo).
*
* Estratégia: abre o arquivo do primeiro estado (AC) e usa o comando
* append em loop para adicionar as demais UFs sequencialmente.
* O resultado é uma base nacional única com todos os indivíduos do Brasil.
*
* ATENÇÃO: Este processo gera um arquivo muito grande (vários GB).
* Certifique-se de ter espaço em disco suficiente antes de executar.
* ===========================================================================

* Define a lista com as siglas das 27 UFs
* A lista começa com AL pois AC já será aberto com o comando use
local ufs "AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO"

* Abre o arquivo do Acre como base inicial
use CENSO10_AC_pes.dta, clear

* Loop que percorre cada UF e acrescenta seus dados à base
* O append adiciona as linhas ao final da base já carregada em memória
foreach uf in `ufs' {
    append using CENSO10_`uf'_pes.dta
}

* Salva a base nacional consolidada
* replace sobrescreve o arquivo se ele já existir
save CENSO10_BR.dta, replace


* ===========================================================================
* PARTE 3 — DEFINIÇÃO DA POPULAÇÃO DE ANÁLISE
*
* A análise foca em adultos com 24 anos ou mais, idade a partir da qual
* a maioria dos indivíduos já concluiu ou abandonou o processo educacional
* formal, permitindo uma classificação mais estável por escolaridade.
*
* As variáveis criadas são binárias (0 ou 1):
*   1 = o indivíduo pertence ao grupo definido
*   0 = o indivíduo não pertence ao grupo
*
* A lógica do Stata é:
*   gen variavel = (condição)
*   O Stata avalia a condição e atribui 1 se verdadeira, 0 se falsa.
* ===========================================================================

* Indicadores base: identifica mulheres e homens com 24 anos ou mais
* v0601 == 2 identifica mulheres; v6036 >= 24 filtra a idade mínima
gen mulher_24 = (v0601 == 2 & v6036 >= 24)
gen homem_24  = (v0601 == 1 & v6036 >= 24)

* ---------------------------------------------------------------------------
* Recorte por nível de escolaridade
*
* Três grupos são criados para cada sexo:
*   _sup  = ensino superior completo (v6400 == 4)
*   _med  = ensino médio completo (v6400 == 3)
*   _fund = fundamental completo ou incompleto, ou sem instrução
*           usa inlist() para aceitar múltiplos valores: v6400 == 1 ou 2
*
* Note que o indivíduo só pode pertencer a um grupo de cada vez.
* O recorte de idade (mulher_24 ou homem_24) garante que apenas adultos
* com 24+ sejam classificados.
* ---------------------------------------------------------------------------

gen mulher_sup  = (mulher_24 == 1 & v6400 == 4)
gen mulher_med  = (mulher_24 == 1 & v6400 == 3)
gen mulher_fund = (mulher_24 == 1 & inlist(v6400, 1, 2))

gen homem_sup   = (homem_24 == 1 & v6400 == 4)
gen homem_med   = (homem_24 == 1 & v6400 == 3)
gen homem_fund  = (homem_24 == 1 & inlist(v6400, 1, 2))


* ===========================================================================
* PARTE 4 — ATIVIDADE ECONÔMICA POR SEXO E ESCOLARIDADE
*
* A variável v6900 indica a condição de atividade econômica.
* Valor 1 = economicamente ativo (inclui ocupados e desocupados
* que estão procurando emprego, conforme definição do IBGE).
*
* Para cada grupo de sexo × escolaridade, criamos uma variável que
* indica se o indivíduo é economicamente ativo.
* Estas variáveis serão usadas para calcular a taxa de participação
* após a agregação municipal.
* ===========================================================================

gen mulher_sup_ativa  = (mulher_sup  == 1 & v6900 == 1)
gen mulher_med_ativa  = (mulher_med  == 1 & v6900 == 1)
gen mulher_fund_ativa = (mulher_fund == 1 & v6900 == 1)
gen mulher_ativa      = (mulher_24   == 1 & v6900 == 1)

gen homem_sup_ativa   = (homem_sup   == 1 & v6900 == 1)
gen homem_med_ativa   = (homem_med   == 1 & v6900 == 1)
gen homem_fund_ativa  = (homem_fund  == 1 & v6900 == 1)
gen homem_ativa       = (homem_24    == 1 & v6900 == 1)


* ===========================================================================
* PARTE 5 — RESIDÊNCIA RURAL E URBANA POR SEXO E ESCOLARIDADE
*
* A variável v1006 indica a situação do domicílio:
*   1 = Urbano (cidade ou vila)
*   2 = Rural (todos os outros casos)
*
* Criamos variáveis separadas para rural e urbano porque o indicador
* final de proporção rural é calculado como:
*   rural / (rural + urbano)
* e não como rural / total, pois pode haver casos sem informação de
* situação do domicílio que não devem entrar no denominador.
* ===========================================================================

* Mulheres rurais por escolaridade
gen mulher_sup_rural   = (mulher_sup  == 1 & v1006 == 2)
gen mulher_med_rural   = (mulher_med  == 1 & v1006 == 2)
gen mulher_fund_rural  = (mulher_fund == 1 & v1006 == 2)
gen mulher_rural       = (mulher_24   == 1 & v1006 == 2)

* Mulheres urbanas por escolaridade (necessário para o denominador)
gen mulher_sup_urbana  = (mulher_sup  == 1 & v1006 == 1)
gen mulher_med_urbana  = (mulher_med  == 1 & v1006 == 1)
gen mulher_fund_urbana = (mulher_fund == 1 & v1006 == 1)

* Homens rurais por escolaridade
gen homem_sup_rural    = (homem_sup   == 1 & v1006 == 2)
gen homem_med_rural    = (homem_med   == 1 & v1006 == 2)
gen homem_fund_rural   = (homem_fund  == 1 & v1006 == 2)
gen homem_rural        = (homem_24    == 1 & v1006 == 2)

* Homens urbanos por escolaridade (necessário para o denominador)
gen homem_sup_urbana   = (homem_sup   == 1 & v1006 == 1)
gen homem_med_urbana   = (homem_med   == 1 & v1006 == 1)
gen homem_fund_urbana  = (homem_fund  == 1 & v1006 == 1)


* ===========================================================================
* PARTE 6 — ESTADO CIVIL POR SEXO E ESCOLARIDADE
*
* A variável v0640 indica o estado civil do indivíduo.
* Valor 1 = casado/a (união formal registrada em cartório).
* Outros valores indicam solteiro, viúvo, separado, divorciado ou
* união consensual.
*
* O indicador final será a proporção de casados/as em cada grupo,
* calculada após a agregação municipal.
* ===========================================================================

gen mulher_sup_casada  = (mulher_sup  == 1 & v0640 == 1)
gen mulher_med_casada  = (mulher_med  == 1 & v0640 == 1)
gen mulher_fund_casada = (mulher_fund == 1 & v0640 == 1)
gen mulher_casada      = (mulher_24   == 1 & v0640 == 1)

gen homem_sup_casado   = (homem_sup   == 1 & v0640 == 1)
gen homem_med_casado   = (homem_med   == 1 & v0640 == 1)
gen homem_fund_casado  = (homem_fund  == 1 & v0640 == 1)
gen homem_casado       = (homem_24    == 1 & v0640 == 1)


* ===========================================================================
* PARTE 7 — RENDIMENTO POR SEXO E ESCOLARIDADE
*
* A variável v6525 contém o rendimento mensal do indivíduo em reais,
* somando todas as fontes de renda (trabalho, aposentadoria, etc.).
* Valor 0 indica ausência de rendimento.
*
* Estratégia de cálculo do rendimento médio ponderado:
*   1. Criamos uma variável binária indicando quem tem renda > 0
*   2. Criamos uma variável com o valor do rendimento, válida apenas
*      para quem tem renda > 0 (os demais ficam como missing/.)
*   3. Após o collapse, o rendimento médio é:
*      media = soma(rendimento) / n(com renda > 0)
*
* Esta abordagem é equivalente à média condicional E[renda | renda > 0],
* que exclui os sem renda do denominador — decisão metodológica que
* deve ser explicitada na tese.
* ===========================================================================

* Indicadores binários: quem tem renda positiva em cada grupo
gen mulher_sup_renda  = (mulher_sup  == 1 & v6525 > 0)
gen mulher_med_renda  = (mulher_med  == 1 & v6525 > 0)
gen mulher_fund_renda = (mulher_fund == 1 & v6525 > 0)
gen mulher_renda      = (mulher_24   == 1 & v6525 > 0)

gen homem_sup_renda   = (homem_sup   == 1 & v6525 > 0)
gen homem_med_renda   = (homem_med   == 1 & v6525 > 0)
gen homem_fund_renda  = (homem_fund  == 1 & v6525 > 0)
gen homem_renda       = (homem_24    == 1 & v6525 > 0)

* Valores de rendimento condicionais à renda positiva
* O "if" cria missing (.) para quem não tem renda > 0
* No collapse, o sum() com pweight ignora automaticamente os missings
gen renda_mulher_sup_valor  = v6525 if mulher_sup_renda  == 1
gen renda_homem_sup_valor   = v6525 if homem_sup_renda   == 1
gen renda_mulher_med_valor  = v6525 if mulher_med_renda  == 1
gen renda_homem_med_valor   = v6525 if homem_med_renda   == 1
gen renda_mulher_fund_valor = v6525 if mulher_fund_renda == 1
gen renda_homem_fund_valor  = v6525 if homem_fund_renda  == 1
gen renda_mulher_total      = v6525 if mulher_renda      == 1
gen renda_homem_total       = v6525 if homem_renda       == 1


* ===========================================================================
* PARTE 8 — FECUNDIDADE POR ESCOLARIDADE
*
* A variável v6633 registra o número total de filhos nascidos vivos
* que a mulher teve ao longo da vida. Esta variável é coletada apenas
* para mulheres no Censo 2010.
*
* O indicador final será a taxa de fecundidade municipal por escolaridade:
*   tx_fecund = soma(filhos) / n(mulheres no grupo)
*
* Nota: esta é uma medida de fecundidade acumulada (filhos já nascidos),
* não uma taxa de fecundidade período. Deve ser interpretada como
* paridade média das mulheres adultas no município.
* ===========================================================================

* Mantém o valor de filhos apenas para mulheres no grupo correspondente
* Mulheres fora do grupo ficam como missing e não entram no collapse
gen filhos_sup  = v6633 if mulher_sup  == 1
gen filhos_med  = v6633 if mulher_med  == 1
gen filhos_fund = v6633 if mulher_fund == 1


* ===========================================================================
* PARTE 9 — AGREGAÇÃO MUNICIPAL COM PESO AMOSTRAL
*
* O comando collapse transforma a base individual em base municipal.
* Cada linha passa a representar um município, e as variáveis tornam-se
* somas ponderadas dos indivíduos que pertencem a cada município.
*
* Sintaxe: collapse (função) variaveis [pweight = peso], by(grupo)
*
*   (sum) = soma todos os valores da variável dentro do município
*   [pweight = v0010] = pondera cada observação pelo seu peso amostral
*   by(munic) = agrupa pelo código do município
*
* O uso de pweight é essencial porque o Censo é uma pesquisa amostral:
* cada entrevistado representa um número diferente de pessoas reais
* na população. O peso v0010 é o fator de expansão que faz essa
* correspondência.
*
* Após o collapse, cada variável contém a soma ponderada dos indivíduos
* de cada grupo dentro de cada município — não mais valores individuais.
* ===========================================================================

collapse (sum) mulher_sup mulher_med mulher_fund mulher_24 homem_sup homem_med homem_fund homem_24 mulher_ativa mulher_sup_ativa mulher_med_ativa mulher_fund_ativa homem_ativa homem_sup_ativa homem_med_ativa homem_fund_ativa mulher_sup_rural mulher_sup_urbana mulher_med_rural mulher_med_urbana mulher_fund_rural mulher_fund_urbana mulher_rural homem_sup_rural homem_sup_urbana homem_med_rural homem_med_urbana homem_fund_rural homem_fund_urbana homem_rural mulher_sup_casada mulher_med_casada mulher_fund_casada mulher_casada homem_sup_casado homem_med_casado homem_fund_casado homem_casado mulher_sup_renda mulher_med_renda mulher_fund_renda mulher_renda homem_sup_renda homem_med_renda homem_fund_renda homem_renda renda_mulher_sup_valor renda_mulher_med_valor renda_mulher_fund_valor renda_mulher_total renda_homem_sup_valor renda_homem_med_valor renda_homem_fund_valor renda_homem_total filhos_sup filhos_med filhos_fund [pweight = v0010], by(munic)



* ===========================================================================
* PARTE 10 — CÁLCULO DOS INDICADORES FINAIS
*
* Após o collapse, as variáveis contêm somas ponderadas.
* Agora calculamos os indicadores percentuais e razões a partir dessas somas.
*
* Lógica geral dos indicadores percentuais:
*   indicador = 100 * (numerador / denominador)
*
* Lógica da razão logarítmica de rendimento:
*   rendM_rendH = ln(renda_media_mulher / renda_media_homem)
*   Valores negativos: mulheres recebem menos que homens
*   Valor zero: paridade salarial
*   Valores positivos: mulheres recebem mais que homens
* ===========================================================================

* ---------------------------------------------------------------------------
* 10.1 Taxa de participação na força de trabalho (%)
*
* Numerador: n ponderado de ativos no grupo (sexo × escolaridade)
* Denominador: n ponderado total no grupo
* ---------------------------------------------------------------------------

gen part_mulher_sup  = 100 * (mulher_sup_ativa  / mulher_sup)
gen part_mulher_med  = 100 * (mulher_med_ativa  / mulher_med)
gen part_mulher_fund = 100 * (mulher_fund_ativa / mulher_fund)
gen part_mulher      = 100 * (mulher_ativa      / mulher_24)

gen part_homem_sup   = 100 * (homem_sup_ativa   / homem_sup)
gen part_homem_med   = 100 * (homem_med_ativa   / homem_med)
gen part_homem_fund  = 100 * (homem_fund_ativa  / homem_fund)
gen part_homem       = 100 * (homem_ativa       / homem_24)

* ---------------------------------------------------------------------------
* 10.2 Proporção rural (%)
*
* Numerador: n ponderado de rurais no grupo
* Denominador: n ponderado de rurais + urbanos no grupo
* (exclui do denominador possíveis missings de situação do domicílio)
* ---------------------------------------------------------------------------

gen mulher_rural_sup   = 100 * (mulher_sup_rural  / (mulher_sup_rural  + mulher_sup_urbana))
gen mulher_rural_medio = 100 * (mulher_med_rural  / (mulher_med_rural  + mulher_med_urbana))
gen mulher_rural_fund  = 100 * (mulher_fund_rural / (mulher_fund_rural + mulher_fund_urbana))
gen mulher_rural_total = 100 * (mulher_rural      / mulher_24)

gen homem_rural_sup    = 100 * (homem_sup_rural   / (homem_sup_rural   + homem_sup_urbana))
gen homem_rural_medio  = 100 * (homem_med_rural   / (homem_med_rural   + homem_med_urbana))
gen homem_rural_fund   = 100 * (homem_fund_rural  / (homem_fund_rural  + homem_fund_urbana))
gen homem_rural_total  = 100 * (homem_rural       / homem_24)

* ---------------------------------------------------------------------------
* 10.3 Proporção de casados/as (%)
*
* Numerador: n ponderado de casados/as no grupo
* Denominador: n ponderado total no grupo
* ---------------------------------------------------------------------------

gen mulheres_casada_sup  = 100 * (mulher_sup_casada  / mulher_sup)
gen mulheres_casada_med  = 100 * (mulher_med_casada  / mulher_med)
gen mulheres_casada_fund = 100 * (mulher_fund_casada / mulher_fund)
gen mulheres_casada      = 100 * (mulher_casada      / mulher_24)

gen homens_casado_sup    = 100 * (homem_sup_casado   / homem_sup)
gen homens_casado_med    = 100 * (homem_med_casado   / homem_med)
gen homens_casado_fund   = 100 * (homem_fund_casado  / homem_fund)
gen homens_casado        = 100 * (homem_casado       / homem_24)

* ---------------------------------------------------------------------------
* 10.4 Rendimento médio e razão logarítmica mulher/homem
*
* Passo 1: calcula o rendimento médio ponderado
*   media = soma(rendimento * peso) / soma(indicador_renda * peso)
*   O denominador é a contagem ponderada de quem tem renda > 0
*
* Passo 2: calcula a razão logarítmica
*   rendM_rendH = ln(media_mulher / media_homem)
* ---------------------------------------------------------------------------

gen media_renda_mulher_sup  = renda_mulher_sup_valor  / mulher_sup_renda
gen media_renda_homem_sup   = renda_homem_sup_valor   / homem_sup_renda
gen rendM_rendH_sup         = ln(media_renda_mulher_sup  / media_renda_homem_sup)

gen media_renda_mulher_med  = renda_mulher_med_valor  / mulher_med_renda
gen media_renda_homem_med   = renda_homem_med_valor   / homem_med_renda
gen rendM_rendH_med         = ln(media_renda_mulher_med  / media_renda_homem_med)

gen media_renda_mulher_fund = renda_mulher_fund_valor / mulher_fund_renda
gen media_renda_homem_fund  = renda_homem_fund_valor  / homem_fund_renda
gen rendM_rendH_fund        = ln(media_renda_mulher_fund / media_renda_homem_fund)

gen media_renda_mulher      = renda_mulher_total      / mulher_renda
gen media_renda_homem       = renda_homem_total       / homem_renda
gen rendM_rendH             = ln(media_renda_mulher   / media_renda_homem)

* ---------------------------------------------------------------------------
* 10.5 Taxa de fecundidade por escolaridade
*
* Numerador: soma ponderada do número de filhos nascidos vivos
* Denominador: n ponderado de mulheres no grupo de escolaridade
*
* Resultado: número médio de filhos por mulher no município,
* por nível de escolaridade (medida de fecundidade acumulada)
* ---------------------------------------------------------------------------

gen tx_fecund_superior = filhos_sup  / mulher_sup
gen tx_fecund_med      = filhos_med  / mulher_med
gen tx_fecund_fund     = filhos_fund / mulher_fund


* ===========================================================================
* PARTE 11 — SALVAMENTO DA BASE MUNICIPAL FINAL
*
* AJUSTE AQUI o caminho de destino antes de executar.
* ===========================================================================

* Salva em formato Stata
save "AJUSTE_AQUI/data_processed/censo2010_municipios.dta", replace

* Exporta também em CSV para maior interoperabilidade
export delimited "AJUSTE_AQUI/data_processed/censo2010_municipios.csv", replace