# Dicionário de Variáveis
## Indicadores Municipais de Gênero e Mercado de Trabalho
### Censo Demográfico 2010 — IBGE

---

## Sobre este dicionário

Este documento descreve todos os indicadores municipais construídos a
partir dos microdados do Censo Demográfico 2010, obtidos via pacote
`datazoom_social` (DataZoom/PUC-Rio):
https://github.com/datazoompuc/datazoom_social_Stata

Os indicadores foram produzidos em duas etapas:

**Etapa 1 — Nível individual:** criação de variáveis binárias (0/1) para
cada indivíduo, indicando se ele pertence a determinado grupo
(sexo × escolaridade × característica de interesse).

**Etapa 2 — Agregação municipal:** uso do comando `collapse` no Stata
(equivalente ao `group_by + summarise` no R) com peso amostral `v0010`
para transformar a base individual em uma base com uma linha por município.
Os indicadores finais são calculados a partir das somas ponderadas geradas
nesta etapa.

---

## Unidade de análise e população de referência

| Item | Descrição |
|------|-----------|
| Unidade de análise | Município (código IBGE, 7 dígitos) |
| Variável de identificação | `munic` |
| População de referência | Indivíduos com 24 anos ou mais |
| Peso amostral | `v0010` (fator de expansão do Censo 2010) |
| Fonte dos microdados | Censo Demográfico 2010 — IBGE |
| Acesso aos microdados | Pacote `datazoom_social` (DataZoom/PUC-Rio) |

**Por que 24 anos ou mais?**
A idade mínima de 24 anos foi adotada porque, nessa faixa etária, a
maioria dos indivíduos já concluiu ou definitivamente abandonou o processo
de escolarização formal. Isso permite uma classificação mais estável por
nível de instrução e evita distorções causadas por indivíduos ainda em
transição educacional.

---

## Níveis de escolaridade

Os indivíduos são classificados em três grupos mutuamente exclusivos,
com base na variável `v6400` do Censo 2010:

| Grupo | Código | Variável v6400 | Descrição |
|-------|--------|----------------|-----------|
| Fundamental | `fund` | 1 ou 2 | Sem instrução, fundamental incompleto ou fundamental completo |
| Médio | `med` | 3 | Ensino médio completo |
| Superior | `sup` | 4 | Ensino superior completo |

**Nota:** o grupo fundamental agrega os códigos 1 (sem instrução ou
fundamental incompleto) e 2 (fundamental completo) para garantir
tamanho amostral adequado nos municípios menores.

---

## Variáveis do Censo 2010 utilizadas na construção

| Variável | Descrição | Valores relevantes |
|----------|-----------|-------------------|
| `v0601` | Sexo | 1 = Homem, 2 = Mulher |
| `v6036` | Idade | Valor numérico em anos |
| `v6400` | Nível de instrução | 1 a 4 (ver tabela acima) |
| `v6900` | Condição de atividade econômica | 1 = Economicamente ativo |
| `v1006` | Situação do domicílio | 1 = Urbano, 2 = Rural |
| `v0640` | Estado civil | 1 = Casado/a |
| `v6525` | Rendimento mensal total (R$) | 0 = sem rendimento |
| `v6633` | Filhos nascidos vivos | Valor numérico (só mulheres) |
| `v0010` | Peso amostral | Fator de expansão |
| `munic` | Código do município | 7 dígitos IBGE |

---

## Indicadores finais — descrição detalhada

---

### 1. Participação na força de trabalho

Mede a proporção de indivíduos economicamente ativos dentro de cada
grupo de sexo e escolaridade no município.

**Definição de economicamente ativo (v6900 = 1):** inclui tanto os
ocupados (com trabalho na semana de referência) quanto os desocupados
que estavam procurando emprego, conforme a metodologia do IBGE.

**Fórmula:**
```
indicador = 100 × (n ativos no grupo) / (n total no grupo)
```

Onde todos os valores são somas ponderadas pelo peso amostral v0010.

| Variável | Grupo | Numerador | Denominador |
|----------|-------|-----------|-------------|
| `part_mulher_sup` | Mulheres com superior | mulheres ativas com superior | total mulheres com superior |
| `part_mulher_med` | Mulheres com médio | mulheres ativas com médio | total mulheres com médio |
| `part_mulher_fund` | Mulheres com fundamental | mulheres ativas com fundamental | total mulheres com fundamental |
| `part_homem_sup` | Homens com superior | homens ativos com superior | total homens com superior |
| `part_homem_med` | Homens com médio | homens ativos com médio | total homens com médio |
| `part_homem_fund` | Homens com fundamental | homens ativos com fundamental | total homens com fundamental |

**Interpretação:** valores mais altos indicam maior inserção no mercado
de trabalho. O diferencial entre `part_mulher_X` e `part_homem_X` para
o mesmo nível de escolaridade captura a desigualdade de gênero na
participação laboral.

---

### 2. Proporção rural por sexo e escolaridade

Mede a proporção de indivíduos que residem em área rural dentro de
cada grupo de sexo e escolaridade no município.

**Fórmula:**
```
indicador = 100 × (n rurais no grupo) / (n rurais + n urbanos no grupo)
```

O denominador usa a soma de rurais e urbanos — e não o total do grupo —
para excluir eventuais casos sem informação de situação do domicílio.

| Variável | Grupo |
|----------|-------|
| `mulher_rural_sup` | Mulheres com superior em área rural (%) |
| `mulher_rural_medio` | Mulheres com médio em área rural (%) |
| `mulher_rural_fund` | Mulheres com fundamental em área rural (%) |
| `homem_rural_sup` | Homens com superior em área rural (%) |
| `homem_rural_medio` | Homens com médio em área rural (%) |
| `homem_rural_fund` | Homens com fundamental em área rural (%) |

**Interpretação:** este indicador captura a distribuição espacial da
população por escolaridade e sexo. Em geral, populações com maior
escolaridade tendem a concentrar-se em áreas urbanas. Municípios com
alta proporção rural e baixa escolaridade podem apresentar padrões
distintos de participação feminina e fecundidade.

---

### 3. Proporção de casados/as por sexo e escolaridade

Mede a proporção de indivíduos casados formalmente (v0640 = 1) dentro
de cada grupo de sexo e escolaridade no município.

**Nota metodológica importante:** a variável v0640 registra apenas o
casamento formal (registrado em cartório). Uniões consensuais são
registradas separadamente no Censo 2010 e **não** estão incluídas neste
indicador. Portanto, os valores podem subestimar a proporção de
indivíduos em algum tipo de união conjugal, especialmente em municípios
com maior prevalência de uniões informais.

**Fórmula:**
```
indicador = 100 × (n casados/as no grupo) / (n total no grupo)
```

| Variável | Grupo |
|----------|-------|
| `mulheres_casada_sup` | Mulheres com superior casadas formalmente (%) |
| `mulheres_casada_med` | Mulheres com médio casadas formalmente (%) |
| `mulheres_casada_fund` | Mulheres com fundamental casadas formalmente (%) |
| `homens_casado_sup` | Homens com superior casados formalmente (%) |
| `homens_casado_med` | Homens com médio casados formalmente (%) |
| `homens_casado_fund` | Homens com fundamental casados formalmente (%) |

---

### 4. Razão logarítmica de rendimento mulher/homem

Mede a desigualdade salarial entre mulheres e homens do mesmo nível de
escolaridade no município, expressa em logaritmo natural.

**Fórmula em duas etapas:**

Etapa 1 — Rendimento médio condicional (apenas com renda > 0):
```
media_renda_mulher_X = soma(rendimento × peso | renda > 0) /
                       soma(1 × peso | renda > 0)
```

Etapa 2 — Razão logarítmica:
```
rendM_rendH_X = ln(media_renda_mulher_X / media_renda_homem_X)
```

**Por que usar o logaritmo natural?**
A razão logarítmica é uma medida simétrica e conveniente para comparações:
- Facilita a interpretação em modelos de regressão (coeficiente ≈ diferença percentual)
- É simétrica: uma vantagem masculina de 50% e uma vantagem feminina de 50% têm o mesmo valor absoluto em módulo
- É comparável entre municípios com níveis absolutos de rendimento muito diferentes

**Interpretação dos valores:**
```
rendM_rendH < 0  →  mulheres recebem MENOS que homens (situação predominante)
rendM_rendH = 0  →  paridade salarial entre mulheres e homens
rendM_rendH > 0  →  mulheres recebem MAIS que homens
```

| Variável | Grupo de comparação |
|----------|---------------------|
| `rendM_rendH_sup` | ln(renda média mulher sup / renda média homem sup) |
| `rendM_rendH_med` | ln(renda média mulher med / renda média homem med) |
| `rendM_rendH_fund` | ln(renda média mulher fund / renda média homem fund) |

**Nota:** o rendimento utilizado é v6525 (rendimento mensal de todas as
fontes), calculado apenas para indivíduos com renda positiva. Indivíduos
sem rendimento são excluídos do denominador — portanto, este é um
indicador de desigualdade entre quem trabalha e recebe, não da população
total.

---

### 5. Taxa de fecundidade por escolaridade

Mede o número médio de filhos nascidos vivos por mulher, por nível de
escolaridade, no município.

**Nota importante:** este indicador é uma medida de **fecundidade
acumulada** (ou paridade), não uma taxa de fecundidade período. Ele
reflete o número total de filhos que as mulheres adultas (24+) já
tiveram ao longo da vida até o momento do Censo, e não a fecundidade
recente do município.

**Fórmula:**
```
tx_fecund_X = soma(filhos nascidos vivos × peso | mulher no grupo X) /
              soma(1 × peso | mulher no grupo X)
```

| Variável | Grupo |
|----------|-------|
| `tx_fecund_superior` | Número médio de filhos por mulher com superior completo |
| `tx_fecund_med` | Número médio de filhos por mulher com médio completo |
| `tx_fecund_fund` | Número médio de filhos por mulher com fundamental |

**Interpretação:** em geral, espera-se uma relação negativa entre
escolaridade e fecundidade acumulada — mulheres com maior escolaridade
tendem a ter menos filhos. Variações municipais neste padrão podem
indicar heterogeneidades culturais, econômicas e de acesso a serviços
de saúde reprodutiva.

---

## Referências

IBGE. **Censo Demográfico 2010 — Notas metodológicas**.
Rio de Janeiro: IBGE, 2010.
Disponível em: https://www.ibge.gov.br/estatisticas/sociais/populacao/9662-censo-demografico-2010.html

DataZoom/PUC-Rio. **datazoom_social_Stata**: acesso facilitado aos
microdados sociais brasileiros no Stata.
Disponível em: https://github.com/datazoompuc/datazoom_social_Stata