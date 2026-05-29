## Gerando indicadores agregados através dos microdados do Censo Demográfico 2010

Repositório de documentação e reprodutibilidade com base no meu segundo ensaio da
tese de doutorado. Contém os scripts de construção de indicadores
municipais de gênero a partir dos microdados do Censo Demográfico 2010
(IBGE), bem como a base municipal processada e o dicionário de variáveis.

---

## Sumário

- [Contexto e objetivo](#contexto-e-objetivo)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Dados](#dados)
- [Como obter os microdados](#como-obter-os-microdados)
- [Metodologia de construção dos indicadores](#metodologia-de-construção-dos-indicadores)
- [Scripts](#scripts)
- [Como reproduzir](#como-reproduzir)
- [Outputs](#outputs)
- [O que revisar antes de usar](#o-que-revisar-antes-de-usar)
- [Referências](#referências)
- [Autora](#autora)

---

## Contexto e objetivo

Este repositório documenta a construção de uma base de dados municipais
utilizada no segundo ensaio da tese de doutorado em Desenvolvimento
Econômico (UFPR). O ensaio analisa desigualdades de gênero no mercado
de trabalho brasileiro, com foco nas diferenças entre mulheres e homens
segundo o nível de escolaridade.

Os indicadores foram construídos a partir dos microdados individuais do
Censo Demográfico 2010 e agregados ao nível municipal, permitindo análises
econométricas que exploram a variação entre os 5.564
municípios brasileiros.

**Dimensões analisadas:**
- Participação das mulheres e homens na força de trabalho
- Distribuição rural/urbana por gênero e escolaridade
- Estado civil por gênero e escolaridade
- Desigualdade salarial entre mulheres e homens (razão logarítmica)
- Fecundidade por nível de escolaridade

---

## Estrutura do repositório

```
segundo-ensaio/
│
├── code/
│   ├── 01_build_census2010_indicators.do   # Script principal em Stata
│   └── 01_build_census2010_indicators.R    # Versão conceitual em R
│
├── data_raw/                               # Microdados brutos — NÃO versionados
│                                           # Devem ser baixados localmente
│                                           # via datazoom_social
│
├── data_processed/
│   └── censo2010_municipios.csv            # Base municipal final — disponível
│                                           # para uso direto sem reprocessar
│
├── docs/
│   └── variable_dictionary.md             # Dicionário completo das variáveis
│
├── outputs/
│   ├── figures/                            # Figuras e gráficos (a serem gerados)
│   └── tables/                             # Tabelas de resultados (a serem geradas)
│
├── .gitignore                              # Arquivos excluídos do versionamento
└── README.md                               # Este arquivo
```

---

## Dados

| Item | Descrição |
|------|-----------|
| **Fonte** | Censo Demográfico 2010 — IBGE |
| **Acesso** | Pacote `datazoom_social` (DataZoom/PUC-Rio) |
| **Referência do pacote** | https://github.com/datazoompuc/datazoom_social_Stata |
| **Período** | Ano de referência: 2010 |
| **Cobertura** | Brasil (5564 munic) |
| **Unidade de análise** | Município (código IBGE, 7 dígitos) |
| **População de referência** | Indivíduos com 24 anos ou mais |
| **Peso amostral** | v0010 (fator de expansão do Censo) |

### Por que os microdados não estão no repositório?

Os microdados brutos do Censo 2010 **não estão incluídos** neste
repositório por duas razões:

1. **Volume:** os arquivos somam vários gigabytes e inviabilizam o
   versionamento no GitHub (limite de 100MB por arquivo)
2. **Origem externa:** os dados são de domínio público do IBGE e devem
   ser obtidos diretamente pela fonte oficial ou via `datazoom_social`

A base municipal processada (`data_processed/censo2010_municipios.csv`)
**está disponível** no repositório e pode ser utilizada diretamente para
análises econométricas sem necessidade de reprocessar os microdados.

---

## Como obter os microdados

Para reproduzir o processamento completo a partir dos microdados brutos,
siga os passos abaixo:

### Passo 1 — Instalar o pacote datazoom_social no Stata

```stata
net install datazoom_social, ///
    from("https://raw.githubusercontent.com/datazoompuc/datazoom_social_Stata/master/")
```

### Passo 2 — Baixar os microdados do Censo 2010

```stata
* Substitua o caminho pelo diretório onde deseja salvar os arquivos
datazoom_censo, years(2010) sample(pes) saving("seu/caminho/local")
```

O comando gera um arquivo `.dta` por Unidade da Federação, no padrão
`CENSO10_XX_pes.dta` (ex: `CENSO10_SP_pes.dta` para São Paulo).

### Passo 3 — Ajustar o caminho no script

Abra o arquivo `code/01_build_census2010_indicators.do` e substitua
`AJUSTE_AQUI` pelo caminho onde os microdados foram salvos.

---

## Metodologia de construção dos indicadores

### Visão geral do processo

```
Microdados individuais          Base nacional          Indicadores municipais
(27 arquivos por UF)    →    (CENSO10_BR.dta)    →    (censo2010_municipios)
   19 milhões obs.             19 milhões obs.           5.564 municípios
```

### Etapa 1 — Empilhamento das UFs

Os 27 arquivos estaduais são empilhados sequencialmente usando `append`
no Stata (ou `bind_rows` no R), formando uma base nacional única com
todos os indivíduos do Brasil.

### Etapa 2 — Criação de variáveis individuais

Para cada indivíduo, criamos variáveis binárias (0 = não pertence,
1 = pertence) indicando sua classificação em cada combinação de
sexo × escolaridade × característica de interesse.

Exemplo: `mulher_sup_ativa = 1` para mulheres com superior completo
que são economicamente ativas; `= 0` para todos os demais.

### Etapa 3 — Agregação municipal

O comando `collapse` no Stata soma todas as variáveis binárias dentro
de cada município, ponderando pelo peso amostral `v0010`:

```stata
collapse (sum) [lista de variáveis] [pweight = v0010], by(munic)
```

Após esta etapa, cada variável contém a **contagem ponderada** de
indivíduos no grupo correspondente em cada município.

### Etapa 4 — Cálculo dos indicadores finais

A partir das contagens ponderadas, calculamos:

| Tipo de indicador | Fórmula geral |
|-------------------|---------------|
| Taxa percentual | `100 × (numerador / denominador)` |
| Razão logarítmica de rendimento | `ln(média_mulher / média_homem)` |
| Taxa de fecundidade | `soma(filhos) / n(mulheres no grupo)` |

### Grupos de análise

Todos os indicadores são calculados para **três grupos de escolaridade**
(fundamental, médio, superior) e para ambos os sexos, gerando
comparações cruzadas de sexo × escolaridade em cada município.

Para descrição detalhada de cada variável, consulte o
[dicionário de variáveis](docs/variable_dictionary.md).

---

## Scripts

### `code/01_build_census2010_indicators.do`

Script principal em **Stata**. Realiza todo o processamento desde o
empilhamento dos arquivos estaduais até o cálculo dos indicadores finais.

**Estrutura interna do script:**

| Parte | Descrição |
|-------|-----------|
| 1 | Configuração do diretório de trabalho |
| 2 | Empilhamento dos 27 arquivos estaduais |
| 3 | Definição da população (sexo, idade, escolaridade) |
| 4 | Variáveis de atividade econômica |
| 5 | Variáveis de residência rural/urbana |
| 6 | Variáveis de estado civil |
| 7 | Variáveis de rendimento |
| 8 | Variáveis de fecundidade |
| 9 | Agregação municipal com peso amostral |
| 10 | Cálculo dos indicadores finais |
| 11 | Salvamento da base municipal |

### `code/01_build_census2010_indicators.R`

Versão conceitual em **R** com sintaxe tidyverse. Replica exatamente a
lógica do script Stata, com comentários detalhados explicando cada
decisão metodológica. Útil para usuários de R que desejam compreender
ou adaptar a metodologia.

**Pacotes R necessários:**

```r
install.packages(c("haven", "dplyr", "purrr", "readr"))
```

| Pacote | Uso |
|--------|-----|
| `haven` | Leitura de arquivos .dta (formato Stata) |
| `dplyr` | Manipulação de dados — filter, mutate, group_by, summarise |
| `purrr` | Iteração funcional — substitui loops for na leitura dos arquivos |
| `readr` | Escrita de arquivos CSV |

---

## Como reproduzir

### No Stata (processamento completo)

```stata
* 1. Instale o datazoom_social (apenas na primeira vez)
net install datazoom_social, ///
    from("https://raw.githubusercontent.com/datazoompuc/datazoom_social_Stata/master/")

* 2. Baixe os microdados do Censo 2010
datazoom_censo, years(2010) sample(pes) saving("seu/caminho/local")

* 3. Ajuste o caminho no script (procure por AJUSTE_AQUI)

* 4. Execute o script
do code/01_build_census2010_indicators.do
```

### No R (versão conceitual)

```r
# 1. Instale os pacotes necessários
install.packages(c("haven", "dplyr", "purrr", "readr"))

# 2. Ajuste DIR_RAW e DIR_PROCESSED no script (procure por AJUSTE_AQUI)

# 3. Execute o script
source("code/01_build_census2010_indicators.R")
```

### Usando diretamente a base processada

Caso não queira reprocessar os microdados, a base municipal final
já está disponível:

```r
library(readr)
municipios <- read_csv("data_processed/censo2010_municipios.csv")
```

```stata
import delimited "data_processed/censo2010_municipios.csv", clear
```

---

## Outputs

| Arquivo | Localização | Descrição |
|---------|-------------|-----------|
| `censo2010_municipios.csv` | `data_processed/` | Base municipal com todos os indicadores — 5564 municípios |
| `variable_dictionary.md` | `docs/` | Dicionário completo com fórmulas e interpretação de cada variável |

---

## O que revisar antes de usar

Antes de utilizar a base ou reexecutar os scripts, verifique:

- [ ] O caminho local nos scripts está ajustado para o seu ambiente
- [ ] Os nomes dos arquivos `.dta` por UF correspondem exatamente ao que o `datazoom_social` gerou
- [ ] As variáveis do Censo (v0601, v6036, v6400, etc.) existem na versão dos microdados que você baixou
- [ ] O peso amostral `v0010` foi aplicado corretamente no `collapse`
- [ ] A variável `munic` tem 7 dígitos e está compatível com outras bases municipais que você usa na tese
- [ ] O indicador `rendM_rendH` usa renda condicional (apenas renda > 0) — isso deve estar explícito na metodologia da tese
- [ ] A taxa de fecundidade é uma medida acumulada, não período — isso deve estar claro na interpretação

---

## Referências

IBGE. **Censo Demográfico 2010**.
Rio de Janeiro: IBGE, 2010.
Disponível em: https://www.ibge.gov.br/estatisticas/sociais/populacao/9662-censo-demografico-2010.html

IBGE. **Notas metodológicas do Censo Demográfico 2010**.
Rio de Janeiro: IBGE, 2010.
Disponível em: https://www.ibge.gov.br/estatisticas/sociais/populacao/9662-censo-demografico-2010.html

DataZoom/PUC-Rio. **datazoom_social_Stata**: acesso facilitado
aos microdados sociais brasileiros no Stata.
Disponível em: https://github.com/datazoompuc/datazoom_social_Stata

---

## Autora

**Carolina Freitas**
Doutora em Desenvolvimento Econômico — UFPR
PUCRS Online

[![GitHub](https://img.shields.io/badge/GitHub-carolinafreitasm-181717?logo=github)](https://github.com/carolinafreitasm)

---

*Repositório de documentação do segundo ensaio da tese de doutorado.
Os microdados brutos não estão incluídos. A base municipal processada
está disponível para uso direto em análises econométricas.*
