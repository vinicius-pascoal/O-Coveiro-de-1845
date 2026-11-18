# O Coveiro de 1845 — Base para o roteiro

Este documento descreve o jogo como ele está implementado hoje: o que o jogador faz, o que o mundo contém e quais peças cada trecho da história precisa ter para caber nas mecânicas. Todo o texto do jogo fica em [scripts/game/narrative.lua](scripts/game/narrative.lua); quem escreve o roteiro só precisa preencher as estruturas descritas aqui.

---

## 1. Premissa em uma frase

Severino Lopes, o novo coveiro de uma vila sergipana em 1845, descobre que o livro de registros de sepultamento é reescrito por uma mão invisível, e precisa decidir o que a vila vai lembrar dos seus mortos, inclusive dele próprio.

**Tema central:** memória como escolha. Quem escreve o registro decide a história; corrigir um nome é devolver uma pessoa à memória da vila, e esconder outro é o preço de uma história "limpa".

---

## 2. O mundo

### Tempo e lugar
- **Vila de Santa Luzia do Paramopama, Sergipe**, novembro de 1845 (o jogo começa em 17/11/1845).
- Vila de porto fluvial: saveiros, lavadeiras, rendeiras, a Matriz com seu sino.
- **A febre de 1844** matou muita gente. A Câmara Municipal escondeu os números para o porto não fechar e os navios não irem embora.
- Tudo é ficcional, inspirado no Sergipe da década de 1840.

### O cemitério (único cenário jogável)
| Lugar | O que é |
|---|---|
| Portão de entrada (sul) | Onde Severino chega. Um papel preso na grade. |
| Sepulturas 01 a 07 | As covas investigadas. A 03 (Joaquina) não é caso, mas muda sozinha. |
| Mesa do livro (fundo) | O livro de registros, sempre aberto, com a lamparina acesa. |
| Arquivo da Câmara (cripta, noroeste) | Papéis úmidos, cheiro de cera velha, documentos oficiais. |
| A vala do fundo | Onde os mortos da febre foram jogados sem cruz. Citada, não visitada. |

### Personagens

**Vivos (ou presentes em cena)**
- **Severino Lopes** — o protagonista e o novo coveiro e zelador, nomeado por ofício da Câmara. Assinou sem perguntar quem escrevia o livro antes dele. Fala só por pensamentos (legenda).
- **Benedito Ramos** — o coveiro anterior, apagado dos registros. Aparece como um vulto que guia Severino: nas noites 1 e 2 é só "O vulto" ou um sussurro, e na noite 3 se revela e o leva até a própria cova.
- **O escrivão do livro** — a "mão que escreve". Uma figura de pé ao lado da lápide lisa, sempre escrevendo. Representa a memória oficial: o livro que mantém a vila coerente devorando nomes.

**Os mortos dos casos** (esqueletos que se levantam quando Severino se aproxima)
- **Antônio Ferreira** — mestre do saveiro Bom Jesus. Pai de Rosa.
- **Maria das Dores Nunes Santos** — lavadeira. Casou com Firmino dos Santos.
- **José de Santana** — sineiro da Matriz por 40 anos.
- **Ana Beatriz de Almeida** — professora de primeiras letras. Irmã de Tomás.
- **Benedito Ramos** — na noite 3 vira o morto da cova 01.

**Citados nos documentos**
- **Padre Inácio** — vigário; casou Maria das Dores e enterrou o sineiro.
- **Rosa Ferreira** — filha de Antônio, mora em Estância.
- **Tomás de Almeida** — irmão de Ana Beatriz.
- **Firmino** — o canteiro que gravou a lápide de Ana. *(Atenção: o marido de Maria das Dores também se chama Firmino dos Santos. Pode ser a mesma pessoa ou um nome a trocar.)*
- **José de Santana, carpinteiro** — homônimo do sineiro, foi para a vala da febre.
- **Joaquina de Jesus** — rendeira, cova 03. A lápide dela passa a dizer: "Viu o zelador sair com o livro."
- **A Câmara Municipal** — a vilã institucional; mandou lançar os mortos da febre com datas espalhadas.

### A verdade por trás de tudo (linha do tempo)
1. **1844:** a febre mata muitos. A Câmara ordena por ofício que os óbitos sejam lançados "com datas diversas e em números separados".
2. **Benedito Ramos**, o zelador, se recusa ("Não escrevo mais o que me mandam"). Deixa uma página rasgada: "Se eu sumir, procurem na primeira cova".
3. Benedito é morto ou apagado. O nome dele é raspado da lápide 01, e o registro fica em branco.
4. O livro passa a se "escrever sozinho": o escrivão mantém a versão oficial e altera lápides (o 6 recém-cortado na pedra de Ana).
5. **Nov/1845:** Severino assume. Na última página, o livro já anuncia: "Severino Lopes, coveiro. Sepultado em 25 de novembro de 1845."

---

## 3. Estrutura do jogo

- **Prólogo:** 3 telas (a vila e a febre; o ofício de nomeação; a chegada na primeira noite).
- **3 noites**, cada uma com título, subtítulo, texto de abertura e texto de fechamento (o fechamento traz o "evento da noite").
- **6 casos** distribuídos pelas noites. Os casos da mesma noite ficam abertos juntos e podem ser resolvidos em qualquer ordem. Um caso pode ficar travado até outro ser resolvido (`requires`).
- **2 finais**, escolhidos no último caso: *Preservar o livro* ou *Revelar a verdade*. Cada final tem 2 páginas de texto, mais uma nota extra se o jogador errou correções.

| Noite | Título | Casos | Evento ao final |
|---|---|---|---|
| 1 | O primeiro nome | c1 Antônio (cova 07), c2 Maria das Dores (cova 02) | Lápide da 03 muda sozinha; aparece a página rasgada de B. R. |
| 2 | As histórias trocadas | c3 José de Santana (cova 04), c4 Ana Beatriz (cova 05) | O testemunho do padre ganha uma frase nova sobre Benedito |
| 3 | O nome que falta | c5 A primeira cova (01), depois c6 A lápide lisa (06) | Final |

---

## 4. Mecânicas (o que o jogador faz)

### 4.1 Explorar
- Primeira pessoa, com WASD para andar, Shift para correr e mouse para olhar.
- As sepulturas de casos abertos ficam marcadas por uma luz fria.
- **Papéis avulsos** brilham pelo cemitério: na mesa, na porta da cripta, no portão e no chão de uma cova. Pegar um papel lê o documento.
- **Sussurros:** frases curtas que disparam ao chegar perto de um lugar, uma vez por campanha. Podem depender da noite ou de um evento.

### 4.2 Ler e anotar (o caderno)
- Mirar numa lápide ou documento e apertar E abre o texto.
- Cada fonte tem **detalhes anotáveis** (pistas) que vão para o caderno (Tab).
- Na primeira leitura de cada documento, Severino solta um **pensamento** (legenda).
- Algumas pistas **provam** o caso. Outras são verdadeiras, mas não provam nada; elas existem para o jogador pensar.

### 4.3 Falar com o morto (confronto)
1. Ao chegar perto da cova, o esqueleto **se levanta** e diz a fala de despertar (balão sobre a cabeça).
2. Ao falar com ele, o morto faz a **pergunta**. Embaixo aparecem as **conclusões** (3 hipóteses).
3. Depois de escolher a conclusão, o morto pergunta "E com o que você prova isso?". O jogador **apresenta uma anotação** do caderno.
4. **Respostas possíveis:**
   - **Conclusão errada:** o morto responde com o feedback daquela hipótese e zomba; a névoa fica mais densa; um sussurro de erro toca.
   - **Conclusão certa, prova fraca:** o morto responde com o feedback específico daquela anotação.
   - **Conclusão certa com prova certa:** o caso fica provado.
5. **Escrever a correção:** o jogador escolhe entre 3 opções para completar a inscrição ou o registro. Uma opção errada gera um feedback e o jogador tenta de novo.
6. **Gravar com o cinzel:** o jogador mira na lápide e segura E. É a correção feita "com a própria mão".
7. **Resolução:** um texto narra o efeito sobrenatural (velas, sino, tremor, clarão). O morto diz a **última fala** e volta a deitar.

### 4.4 O guia (Benedito)
- **Noite 1:** um vulto escrevendo no livro some quando Severino chega perto.
- **Noite 2:** o vulto aparece em pontos do mapa e sussurra onde estão os papéis (uma rota de 3 paradas).
- **Noite 3:** Benedito se revela e guia Severino por um caminho de velas até a cova 01, onde se deita e vira o morto do caso.
- No final, ele se despede de um jeito diferente conforme a escolha.

### 4.5 O escrivão e a decisão final
- O escrivão fica de pé ao lado da lápide lisa e só responde depois que o jogador lê a última página e o bilhete de Benedito.
- A conversa não tem resposta certa: o jogador escolhe Preservar, Revelar ou "Ainda não".
- O escrivão reage à escolha, Benedito se despede e o final começa.

### 4.6 Erros e consequências
- Cada conclusão errada adiciona um sussurro (há 5, em sequência) e deixa uma "cicatriz".
- Se houve erros, o final ganha a nota: *"Algumas correções erradas também ficaram no livro."*
- A ajuda (tecla H) dá a dica do caso sem penalidade.

### 4.7 Onde cada tipo de texto aparece
| Tipo | Onde aparece |
|---|---|
| Falas dos mortos, do Benedito e do escrivão | **Balão** sobre a cabeça de quem fala |
| Pensamentos de Severino, sussurros soltos, narração das correções | **Legenda** embaixo |
| Escolhas do jogador (conclusões, provas, correções) | **Painel** na parte de baixo |
| Documentos | Folha de papel em tela |
| Abertura e fechamento das noites, prólogo, finais | Telas cheias |

---

## 5. Molde de um caso (o que escrever para cada um)

Cada caso precisa das peças abaixo. Copie e preencha:

```
CASO: id / noite / número da cova
Título:
Objetivo (1 linha, aparece na barra de cima):

LÁPIDE ATUAL (o que está errado na pedra):
LÁPIDE CORRIGIDA:

DOCUMENTOS (2 ou 3; dizer se ficam na cova ou num lugar do mapa):
  - Título / subtítulo / texto
  - Pensamento de Severino ao ler (1 frase)

PISTAS ANOTÁVEIS (1–2 por fonte):
  - texto curto da anotação  →  prova? (sim/não)
  - para cada pista que NÃO prova: por que não prova (fala do morto)

O MORTO:
  Fala ao levantar:
  Pergunta do confronto:
  Última fala (depois de corrigido):

PERGUNTA DO CASO:
HIPÓTESES (3; uma certa):
  - texto  →  se errada: resposta do morto

CORREÇÃO:
  Título / modelo com lacuna "____"
  3 opções (uma certa) e a resposta para cada errada

RESOLUÇÃO (narração do efeito sobrenatural, 2 parágrafos curtos):
RESUMO (1 linha para o caderno):
DICA (texto da tecla H):
Pensamento ao começar o caso:
Efeito: clarão (0–1) / tremor (segundos)
```

**Regras que a mecânica impõe ao roteiro**
- A prova certa tem que ser uma **fonte independente** que desempate a contradição, não a própria contradição.
- Cada hipótese errada precisa de um motivo concreto, apontável nos documentos, para estar errada.
- As falas do morto saem num balão: o ideal é até ~2 linhas, em primeira pessoa, no tom do personagem.
- Um documento num lugar do mapa (fora da cova) é uma boa chance para o vulto guiar o jogador até ele.

---

## 6. Ganchos e pontas soltas para o roteiro

- **Quem é o escrivão?** Hoje é só "a mão que escreve o livro". Pode ser a própria Câmara, um antigo vereador, o livro personificado ou o próximo coveiro.
- **Severino no dia 25:** o final *Preservar* sugere que ele morre e o livro já sabia; o *Revelar* apaga a linha com o nome dele. Dá para explorar o que acontece entre os dias 17 e 25.
- **A vala da febre:** dezenas de mortos sem nome. Poderia virar um caso coletivo, ou um epílogo.
- **Joaquina de Jesus (cova 03):** "Viu o zelador sair com o livro." É uma testemunha não explorada; daria um caso extra.
- **Os dois Firminos** (o canteiro e o marido de Maria das Dores): unir os dois numa só pessoa ou separar.
- **Padre Inácio:** sabia de tudo e escreveu "mais do que contou". É um possível aliado ou cúmplice.
- **Rosa Ferreira e Tomás de Almeida:** vivos que poderiam aparecer num epílogo do final *Revelar*.

---

## 7. Limites técnicos atuais (para não escrever o que o jogo não faz)

- **Um só cenário:** o cemitério à noite. Não há cenas na vila.
- **7 sepulturas** existem no mapa. Um caso novo precisa usar uma delas, ou a cena precisa de outra.
- **Personagens em cena** são esqueletos (5 modelos com animações de levantar, falar, zombar, interagir e deitar). Vivos não aparecem em cena; falam por documentos.
- **4 lugares de papel avulso:** mesa, cripta, portão e chão da cova 04. Lugares novos precisam ser colocados na cena.
- **O jogador não digita.** Toda escolha é entre opções (até 5 por tela).
- **Não há narração em voz** nem cutscene com câmera livre; a câmera só se vira para quem fala.
