-- NarrativeData: todo o texto do jogo. Pessoas, lugares e acontecimentos são ficcionais.
-- A lógica (game/flow.lua) e a interface (hud_controller.lua) apenas leem esta tabela.
-- Roteiro de referência: ROTEIRO_O_COVEIRO_DE_1845_JAM (v1.0).
--
-- Cânone: o livro altera seus próprios registros e as lápides; por isso o livro e a pedra
-- costumam contar a mesma mentira. Só papéis independentes (cartas, assentos paroquiais,
-- folhas da irmandade) sobrevivem como vestígio, e são eles que provam cada caso.

local N = {}

N.protagonist = "Severino Lopes"
N.town = "Vila de Santa Luzia do Paramopama"
N.nightCount = 3

----------------------------------------------------------------------
-- Sepulturas (7 no cenário; a 03 não pertence a nenhum caso)
----------------------------------------------------------------------
N.graves = {
    [1] = { number = "01", entity = "Grave01", name = "Sepultura sem nome",
            inscription = "COVA 01\nSEM NOME\n(a pedra foi raspada)" },
    [2] = { number = "02", entity = "Grave02", name = "Maria Nunes",
            inscription = "MARIA NUNES\nLavadeira do Paramopama\nFaleceu em 1845" },
    [3] = { number = "03", entity = "Grave03", name = "Joaquina de Jesus",
            inscription = "JOAQUINA DE JESUS\nRendeira\nFaleceu em 1844" },
    [4] = { number = "04", entity = "Grave04", name = "José de Santana",
            inscription = "JOSÉ DE SANTANA\nCarpinteiro\nFaleceu em 1844" },
    [5] = { number = "05", entity = "Grave05", name = "Ana Beatriz de Almeida",
            inscription = "ANA BEATRIZ DE ALMEIDA\nProfessora de primeiras letras\nFaleceu em 1846" },
    [6] = { number = "06", entity = "Grave06", name = "Lápide lisa",
            inscription = "(A pedra está lisa. Nenhum nome, nenhuma data.)" },
    [7] = { number = "07", entity = "Grave07", name = "Antônio Ferreira",
            inscription = "ANTÔNIO FERREIRA\nMestre do saveiro Bom Jesus\nFaleceu em 12/06/1843" },
}

----------------------------------------------------------------------
-- Documentos (livro de registros e papéis avulsos)
-- kind: "book" (entrada do livro) | "letter" | "testimony" | "record"
-- place: lugar do cemitério onde o papel espera (sem place, é lido na própria sepultura)
-- variants: textos que substituem/complementam o corpo quando uma flag é ativada
----------------------------------------------------------------------
N.evidence = {
    -- Nomeação de Severino, presa no portão na primeira noite (não pertence a nenhum caso)
    ["oficio_nomeacao"] = { kind = "record", place = "gate", title = "Ofício de nomeação",
        subtitle = "Câmara Municipal, novembro de 1845",
        body = "\"Por ordem da Câmara Municipal, Severino Lopes assume o ofício de coveiro e zelador do campo-santo desta vila, com a obrigação de manter em ordem o livro de registros, conforme o que nele estiver escrito.\"\n\nNo lugar do nome do antigo zelador, alguém deixou um espaço em branco." },

    -- c1: Antônio Ferreira
    ["book:07"] = { kind = "book", title = "Livro de registros — nº 07",
        body = "Registro nº 07 — Antônio Ferreira, mestre do saveiro Bom Jesus. Falecido em 12 de junho de 1843.\n\nA tinta é a mesma da pedra: firme, sem rasura." },
    ["bilhete_rosa"] = { kind = "letter", title = "Bilhete de Rosa Ferreira",
        subtitle = "Deixado ao pé da cova 07",
        body = "\"Pai deixou o barco depois da travessia. Ainda tenho sua última carta, guardada com as redes. Não sei mais em que ano ela chegou; só sei que ele ainda ria do rio.\n\nRosa\"" },
    ["assento_antonio"] = { kind = "record", place = "desk", title = "Assento de sepultamento",
        subtitle = "Assinado pelo vigário, Padre Inácio",
        body = "\"Antônio Ferreira, mestre do saveiro Bom Jesus, falecido em 12 de junho de 1845. Sepultamento autorizado no dia seguinte, no campo-santo desta vila.\"\n\nO papel é da paróquia, não da Câmara. O livro nunca o tocou." },

    -- c2: Maria das Dores Nunes Santos
    ["book:02"] = { kind = "book", title = "Livro de registros — nº 02",
        body = "Registro nº 02 — Maria Nunes, lavadeira. Sepultada em 1845.\n\nSó isso. Nem o dia, nem o mês." },
    ["bilhete_firmino"] = { kind = "letter", title = "Bilhete de Firmino dos Santos",
        subtitle = "Canteiro, marido de Maria — preso à cruz da cova 02",
        body = "\"Chamavam-na Maria Nunes, mas em casa era Das Dores. Depois da febre, mandaram gravar somente o nome curto. Eu, que talho pedra para a vila inteira, não tive licença de talhar a dela.\n\nFirmino\"" },
    ["extrato_paroquial"] = { kind = "record", place = "crypt", title = "Extrato paroquial",
        subtitle = "Livros da Matriz — casamentos e sepultamentos",
        body = "Casamento, maio de 1840: \"Firmino dos Santos e Maria das Dores Nunes, lavadeira.\"\n\nSepultamento, agosto de 1844: \"Maria das Dores Nunes Santos, mulher de Firmino dos Santos. Febre.\"\n\nAssina o Padre Inácio." },

    -- c3: José de Santana
    ["book:04"] = { kind = "book", title = "Livro de registros — nº 04",
        body = "Lista de óbitos resumida pela Câmara:\n\n\"José de Santana. Sepultado no nº 04.\"\n\nNenhuma idade. Nenhum ofício. Uma linha só." },
    ["folha_irmandade"] = { kind = "record", place = "grave04", title = "Folha da Irmandade do Sino",
        subtitle = "Caída ao pé da sepultura 04",
        body = "Irmãos falecidos, pela ordem:\n\n• José de Santana, carpinteiro, 27 anos. Febre, 1844. Levado à vala do fundo.\n• José de Santana, sineiro da Matriz por quarenta anos. Sepultado no nº 04, em 1845, com a corda do sino nas mãos." },

    -- c4: Ana Beatriz de Almeida
    ["book:05"] = { kind = "book", title = "Livro de registros — nº 05",
        body = "Registro nº 05 — Ana Beatriz de Almeida, professora de primeiras letras. Falecida em 1846.\n\nO ano ainda não chegou. A tinta não sabe disso." },
    ["carta_tomas"] = { kind = "letter", place = "gate", title = "Carta de Tomás de Almeida",
        subtitle = "Presa na grade do portão",
        body = "\"Voltei à escola meses depois do seu enterro. Suas crianças ainda desenhavam a palavra 'lembrar' nas lousas, do jeito que ela ensinou. Ninguém teve coragem de apagar.\n\nTomás\"" },
    ["comprovante_ana"] = { kind = "record", place = "crypt", title = "Comprovante paroquial de enterro",
        subtitle = "Guardado no arquivo da Câmara",
        body = "\"Ana Beatriz de Almeida, professora de primeiras letras, falecida em 1844, sepultada no mês de outubro do mesmo ano.\"\n\nAssina o Padre Inácio. O papel está úmido, mas a data não mudou." },

    -- c5: a primeira cova
    ["book:01"] = { kind = "book", title = "Livro de registros — nº 01",
        body = "Registro nº 01 — a linha está em branco desde 1844.\n\nHá marcas de raspagem no papel, como se alguém tivesse tirado um nome com a ponta de uma faca." },
    ["pagina_rasgada"] = { kind = "letter", title = "Página rasgada",
        subtitle = "Presa entre as últimas folhas do livro",
        body = "\"...os mortos da febre não cabem no número que a Câmara quer. Não escrevo mais o que me mandam. Se eu sumir, procurem na primeira cova.\"\n\n— B. R." },
    ["testemunho_vigario"] = { kind = "testimony", place = "crypt", title = "Testemunho do Padre Inácio",
        subtitle = "Apareceu no arquivo da Câmara",
        body = "\"Benedito Ramos, zelador do campo-santo, foi enterrado na primeira cova no inverno de 1844. Aceitei que seu nome não fosse escrito.\"\n\nA última linha está fresca:\n\"Era ele quem guardava este livro. Recusei-me a falar quando pediram silêncio.\"" },

    -- c6: a lápide lisa
    ["book:06"] = { kind = "book", title = "Livro de registros — última página",
        body = "Uma linha nova, na mesma letra de todos os registros:\n\n\"Severino Lopes, coveiro. Sepultado em 25 de novembro de 1845.\"\n\nHoje é 17 de novembro de 1845." },
    ["oficio_camara"] = { kind = "record", place = "crypt", title = "Ordem da Câmara sobre a febre",
        subtitle = "Julho de 1844 — achada no arquivo da cripta",
        body = "\"Ordena-se ao zelador que os falecimentos sejam lançados em datas diversas e em números separados, para que o porto não sofra alarme nem perca os navios. O desobediente será dispensado, e seu nome, riscado.\"" },
}

----------------------------------------------------------------------
-- Lugares do cemitério onde papéis avulsos ficam esperando (documentos com place = ...).
-- O papel brilha enquanto guardar um documento de um caso aberto.
----------------------------------------------------------------------
N.places = {
    desk    = { entity = "PaperDesk", label = "o papel sobre a mesa", where = "sobre a mesa do livro, na cabana do coveiro" },
    crypt   = { entity = "PaperCrypt", label = "o papel na porta do arquivo", where = "pregado na porta do arquivo da Câmara (a cripta, a noroeste)" },
    gate    = { entity = "PaperGate", label = "o papel preso no portão", where = "preso na grade do portão de entrada, atrás de você ao chegar" },
    grave04 = { entity = "PaperGrave04", label = "o papel no chão", where = "no chão, ao pé da sepultura 04" },
}

-- Papéis avulsos que não pertencem a caso nenhum: ficam no lugar durante a noite indicada
N.looseDocs = {
    { id = "oficio_nomeacao", night = 1 },
}

----------------------------------------------------------------------
-- Os mortos de cada caso: um esqueleto deitado ao lado da cova que se levanta
-- quando o coveiro chega perto. É a ele que se apresentam as provas.
-- entity = nome na cena World; awaken = fala ao levantar; ask = pergunta no confronto;
-- rest = última fala depois que o registro é corrigido.
----------------------------------------------------------------------
N.spirits = {
    c1 = { entity = "Spirit_c1", name = "Antônio Ferreira",
           awaken = "...tiraram-me dois anos. O rio ainda lembra.",
           ask = "\"De que ano é a minha morte, coveiro?\"",
           rest = "...agora a minha filha pode contar os dias certos." },
    c2 = { entity = "Spirit_c2", name = "Maria das Dores",
           awaken = "...levaram meu sobrenome como se fosse roupa no rio.",
           ask = "\"Quem sou eu neste chão?\"",
           rest = "...meu nome inteiro. Que não me lavem da memória." },
    c3 = { entity = "Spirit_c3", name = "José de Santana",
           awaken = "...um nome, dois homens. Nem o meu sino me reconhece.",
           ask = "\"De quem é o ofício escrito nesta pedra?\"",
           rest = "...que o outro José também seja lembrado, mesmo sem cruz." },
    c4 = { entity = "Spirit_c4", name = "Ana Beatriz de Almeida",
           awaken = "...até o futuro me roubaram.",
           ask = "\"Que ano a pedra deveria contar?\"",
           rest = "...ensinei letras para que os nomes não se perdessem." },
    c5 = { entity = "Spirit_c5", name = "Benedito Ramos",
           awaken = "...passei a vida pondo nome nos outros. Não guardei o meu.",
           ask = "\"Quem repousa na primeira cova?\"",
           rest = "...agora já não precisas que eu te guie." },
    -- A mão que escreve o livro: não se levanta do chão, está de pé escrevendo ao lado da lápide lisa
    c6 = { entity = "Spirit_c6", name = "O escrivão do livro", standing = true,
           awaken = "...sem o livro, a vila terá de lembrar. Sozinha.",
           ask = "\"Teu nome já tem data. Queres mesmo riscá-la?\"",
           notReady = "\"A ordem preservou o porto; o porto preservou a vila. Ninguém assina o que não leu.\"",
           finale = {
               reveal = "...não! Sem mim, cada um vai lembrar de um jeito...",
               preserve = "...bom coveiro. A página do dia 25 já está pronta.",
           } },
}

----------------------------------------------------------------------
-- Benedito Ramos, o coveiro apagado: um vulto que guia cada noite.
-- Cada rota é uma lista de pontos (x, z). Em cada ponto o vulto pode:
--   anim  = animação em loop enquanto espera
--   wait  = { near = r } espera o coveiro chegar a r metros
--   follow = r: ao chegar, espera o coveiro se aproximar a r metros antes de seguir
--   act   = animação que toca uma vez quando a espera acaba; say = fala nesse momento
--   vanish = some depois; lie = deita-se ali (e vira o morto da cova 01)
-- Nas noites 1 e 2 o nome dele ainda não é conhecido: fala como "Sussurro" (balão "O vulto").
----------------------------------------------------------------------
N.benedito = { entity = "Benedito", name = "Benedito Ramos" }

N.guideRoutes = {
    [1] = {
        { x = 6.0, z = -16.1, faceX = 6.0, faceZ = -17.0, anim = "Use_Item", wait = { near = 7 },
          say = { "Severino", "Ouvi o raspar de uma pena. Havia alguém debruçado sobre o livro. Agora não há ninguém." }, vanish = true },
    },
    -- mesa → cova 04 → porta da cripta
    [2] = {
        { x = 4.6, z = -15.3, anim = "Skeletons_Idle", wait = { near = 5 }, act = "Interact",
          say = { "Sussurro", "...o livro diz pouco; procura o que caiu dele..." } },
        { x = 4.0, z = -12.2 },   -- porta da cabana
        { x = 9.0, z = -11.6 },
        { x = 11.0, z = -6.0, anim = "Skeletons_Idle", wait = { near = 4.5 }, act = "Interact",
          say = { "Sussurro", "...dois Josés. Só um ganhou a pedra..." } },
        { x = 9.0, z = -11.6 },
        { x = 3.0, z = -12.2 },
        { x = 0.5, z = -12.6 },
        { x = -2.5, z = -12.4 },
        { x = -5.5, z = -11.4 },
        { x = -8.5, z = -11.0, faceX = -11.0, faceZ = -13.5, anim = "Skeletons_Idle", wait = { near = 4.5 }, act = "Interact",
          say = { "Sussurro", "...o vigário escreveu mais do que contou..." }, vanish = true },
    },
    [3] = {
        { x = 4.6, z = -15.3, anim = "Skeletons_Idle", wait = { near = 8 }, act = "Interact",
          say = { "Benedito", "...fui eu quem te trouxe até aqui. Siga as velas, coveiro." } },
        { x = 4.0, z = -12.2, follow = 8 },   -- porta da cabana
        { x = 0.5, z = -12.6, follow = 8 },
        { x = -2.5, z = -12.4, follow = 8 },
        { x = -5.5, z = -11.4, follow = 8 },
        { x = -8.5, z = -10.4, follow = 8 },
        { x = -10.4, z = -7.4, lie = true,
          say = { "Benedito", "...aqui. Foi aqui que me deixaram, sem nome." } },
    },
}

-- Despedida no final: ao revelar, ele acena e se desfaz; ao preservar, dá as costas e some
N.beneditoFinale = {
    reveal = "...obrigado. Agora eles podem discordar de mim também.",
    preserve = "...então o livro continua com fome.",
}

-- O que o cemitério faz quando um registro é corrigido (além das velas na cova e do clarão da lua)
-- shake = segundos de tremor da câmera; flash = força do clarão
N.resolutionEffects = {
    c1 = { flash = 0.6 },                -- água ao longe
    c2 = { flash = 0.5 },                -- pingos de roupa torcida; o livro treme
    c3 = { flash = 0.4, shake = 0.35 },  -- uma badalada solitária
    c4 = { flash = 0.8 },                -- o 6 perde o brilho; a pena risca sozinha
    c5 = { flash = 1.0, shake = 0.8 },   -- as velas apagam; luz fria na lápide 06
}

-- Sussurros depois de uma conclusão errada (em ordem, um por erro)
N.mistakeWhispers = {
    "...uma pedra lembra o que lhe mandam...",
    "...nem toda tinta é testemunha...",
    "...há nomes demais para tão poucas datas...",
    "...o livro prefere uma história sem falhas...",
    "...teu nome também cabe numa linha...",
}

----------------------------------------------------------------------
-- Detalhes que o jogador pode anotar no caderno, por fonte (lápide ou documento).
-- Alguns provam a conclusão do caso; outros são verdadeiros mas não provam nada.
----------------------------------------------------------------------
N.clues = {
    ["grave:07"] = { { id = "c1_lapide", text = "Lápide: \"Faleceu em 12/06/1843\"" } },
    ["book:07"] = { { id = "c1_livro", text = "Livro: falecido em junho de 1843, como a pedra" } },
    ["bilhete_rosa"] = { { id = "c1_rosa", text = "Rosa se lembra do pai navegando há pouco" } },
    ["assento_antonio"] = {
        { id = "c1_assento", text = "Assento do vigário: morto em 12/06/1845" },
        { id = "c1_autorizado", text = "Assento: sepultamento autorizado no dia seguinte" },
    },

    ["grave:02"] = { { id = "c2_lapide", text = "Lápide: \"Maria Nunes — 1845\"" } },
    ["book:02"] = { { id = "c2_livro", text = "Livro: \"Maria Nunes\", sepultada em 1845" } },
    ["bilhete_firmino"] = { { id = "c2_firmino", text = "Firmino: o nome da lápide está incompleto" } },
    ["extrato_paroquial"] = {
        { id = "c2_extrato", text = "Paróquia: Maria das Dores Nunes Santos, morta em 1844" },
        { id = "c2_casamento", text = "Paróquia: casou com Firmino dos Santos em 1840" },
    },

    ["grave:04"] = { { id = "c3_lapide", text = "Lápide: \"José de Santana, carpinteiro, 1844\"" } },
    ["book:04"] = { { id = "c3_lista", text = "Câmara: um só José de Santana, sem ofício" } },
    ["folha_irmandade"] = {
        { id = "c3_irmandade", text = "Irmandade: dois Josés, carpinteiro (1844) e sineiro (1845)" },
        { id = "c3_corda", text = "Irmandade: o sineiro foi enterrado com a corda do sino" },
    },

    ["grave:05"] = { { id = "c4_lapide", text = "Lápide: \"1846\" — o 6 parece recém-cortado" } },
    ["book:05"] = { { id = "c4_livro", text = "Livro: falecida em 1846" } },
    ["carta_tomas"] = { { id = "c4_tomas", text = "Tomás: voltou à escola meses depois do enterro" } },
    ["comprovante_ana"] = { { id = "c4_comprovante", text = "Comprovante paroquial: morta em 1844" } },

    ["grave:01"] = { { id = "c5_raspado", text = "Lápide: o nome foi raspado da pedra" } },
    ["pagina_rasgada"] = {
        { id = "c5_iniciais", text = "B. R.: \"Não escrevo mais o que me mandam\"" },
        { id = "c5_sumir", text = "B. R.: \"Se eu sumir, procurem na primeira cova\"" },
    },
    ["testemunho_vigario"] = {
        { id = "c5_padre", text = "Padre: Benedito Ramos foi enterrado na primeira cova" },
        { id = "c5_silencio", text = "Padre: \"Recusei-me a falar quando pediram silêncio\"" },
    },
}

----------------------------------------------------------------------
-- Casos. evidence = documentos do caso além da própria lápide.
-- proof: anotações aceitas como prova da hipótese correta (e respostas às outras).
-- fix: a correção que o próprio jogador escreve depois de provar.
-- Na mesma noite os casos ficam abertos juntos; requires trava um caso até outro ser resolvido.
----------------------------------------------------------------------
N.cases = {
    {
        id = "c1", night = 1, grave = 7,
        title = "O mestre que morreu duas vezes",
        objective = "Sepultura 07 — descubra em que ano Antônio Ferreira realmente morreu.",
        evidence = { "book:07", "bilhete_rosa", "assento_antonio" },
        hint = "A pedra e o livro dizem a mesma coisa, e é isso que levanta suspeita. Um assento de sepultamento, não a lembrança da família, pode confirmar a data. Procure na mesa do livro.",
        proof = {
            accept = { "c1_assento" },
            feedback = {
                c1_lapide = "\"A pedra diz o que lhe mandaram dizer. Ela não pode provar a si mesma.\"",
                c1_livro = "\"O livro e a pedra falam com a mesma tinta. Quero uma voz de fora.\"",
                c1_rosa = "\"A memória de Rosa não basta, coveiro. Ela nem sabe o ano.\"",
                c1_autorizado = "\"Um dia depois de quê? Leia a data que vem antes.\"",
            },
        },
        fix = {
            title = "Corrigir a lápide",
            prompt = "ANTÔNIO FERREIRA\nMestre do saveiro Bom Jesus\nFaleceu em 12/06/____",
            options = { "1843", "1845", "1846" },
            correct = 2,
            feedback = {
                [1] = "É a data que você acabou de provar errada. O cinzel para no ar.",
                [3] = "O assento do vigário diz 1845. Não troque uma mentira por outra.",
            },
        },
        question = "O que os documentos sustentam sobre Antônio Ferreira?",
        hypotheses = {
            { text = "Morreu em 1843, como dizem a pedra e o livro.",
              feedback = "\"O vigário pôs outro ano no papel; não o ignores.\"" },
            { text = "A lápide foi antecipada em dois anos: ele morreu em 1845.", correct = true },
            { text = "Nunca foi sepultado: partiu no saveiro.",
              feedback = "\"Barco não carrega quem já deitou na terra.\"" },
        },
        resolution = "Você corrige a data: 1845.\n\nPor um instante, ouve água batendo num casco, longe demais do rio. A lápide brilha de leve e se apaga.",
        newInscription = "ANTÔNIO FERREIRA\nMestre do saveiro Bom Jesus\nFaleceu em 12/06/1845",
        summary = "Sepultura 07: a lápide de Antônio Ferreira foi antecipada em dois anos; ele morreu em 1845.",
    },
    {
        id = "c2", night = 1, grave = 2,
        title = "O nome inteiro",
        objective = "Sepultura 02 — devolva o nome e a data corretos à sepultura de Maria.",
        evidence = { "book:02", "bilhete_firmino", "extrato_paroquial" },
        hint = "A lembrança do marido não basta. O registro da paróquia, guardado na cripta, confirma o nome e o ano sem depender do livro da Câmara.",
        proof = {
            accept = { "c2_extrato" },
            feedback = {
                c2_lapide = "\"Isso é o que me deixaram. Não é o que eu era.\"",
                c2_livro = "\"O livro só repete a pedra. Procure outra escrita.\"",
                c2_firmino = "\"Firmino me conhecia; mas onde está a escrita?\"",
                c2_casamento = "\"Isso diz com quem casei. Não diz quando me enterraram.\"",
            },
        },
        fix = {
            title = "Corrigir a lápide",
            prompt = "Sepultura 02 — ____\nLavadeira do Paramopama",
            options = { "Maria Nunes — 1845", "Maria das Dores Nunes Santos — 1844", "Maria das Dores — 1846" },
            correct = 2,
            feedback = {
                [1] = "É o nome curto e o ano errado: exatamente o que a Câmara mandou gravar.",
                [3] = "Metade do nome e um ano que ainda não chegou. O extrato diz outra coisa.",
            },
        },
        question = "Como resolver a diferença entre a pedra e a vida de Maria?",
        hypotheses = {
            { text = "Maria Nunes e Maria das Dores eram pessoas diferentes.",
              feedback = "\"Meu nome não era outra pessoa.\"" },
            { text = "Ela morreu em 1845 e a família se confunde.",
              feedback = "\"O ano da febre não sai do peito.\"" },
            { text = "O nome foi reduzido e a morte, transferida de 1844 para 1845.", correct = true },
        },
        resolution = "Você grava o nome inteiro: Maria das Dores Nunes Santos, 1844.\n\nOuve pingos, como roupa torcida sobre uma pedra. Na mesa, ao fundo, o livro treme sozinho.",
        newInscription = "MARIA DAS DORES NUNES SANTOS\nLavadeira do Paramopama\nFaleceu em 1844",
        summary = "Sepultura 02: o nome de Maria das Dores Nunes Santos foi encurtado e sua morte, de 1844, mudada para 1845.",
    },
    {
        id = "c3", night = 2, grave = 4,
        title = "Dois Josés, uma lápide",
        objective = "Sepultura 04 — diferencie os dois homens chamados José de Santana.",
        evidence = { "book:04", "folha_irmandade" },
        hint = "A lista da Câmara é a origem da confusão. Procure uma fonte que fale explicitamente dos dois homônimos: há um papel caído ao pé da sepultura 04.",
        proof = {
            accept = { "c3_irmandade" },
            feedback = {
                c3_lapide = "\"Essa pedra é justamente o que está errado.\"",
                c3_lista = "\"O livro só conhece o que deixaram escrever.\"",
                c3_corda = "\"A corda diz quem eu era. Mas quem era o outro?\"",
            },
        },
        fix = {
            title = "Corrigir a lápide",
            prompt = "JOSÉ DE SANTANA\n____",
            options = { "carpinteiro — 1844", "sineiro — 1845", "sineiro — 1846" },
            correct = 2,
            feedback = {
                [1] = "O carpinteiro foi para a vala. A pedra continuaria com o homem errado.",
                [3] = "O ofício está certo, o ano não. A Irmandade diz 1845.",
            },
        },
        question = "Quem está, de fato, na sepultura 04?",
        hypotheses = {
            { text = "O sineiro e o carpinteiro são o mesmo homem.",
              feedback = "\"Eu tocava o sino enquanto ele talhava portas.\"" },
            { text = "Dois homens homônimos foram fundidos num só registro.", correct = true },
            { text = "O sineiro nunca existiu.",
              feedback = "\"Quarenta anos me ouviram do alto da Matriz.\"" },
        },
        resolution = "Você grava: José de Santana, sineiro, 1845.\n\nDo fundo do cemitério vem uma badalada solitária. Alguém sussurra: \"O outro ficou na vala.\"",
        newInscription = "JOSÉ DE SANTANA\nSineiro da Matriz por quarenta anos\nFaleceu em 1845",
        summary = "Sepultura 04: é do sineiro. O carpinteiro de mesmo nome morreu na febre de 1844 e foi para a vala.",
    },
    {
        id = "c4", night = 2, grave = 5,
        title = "O ano que ainda não chegou",
        objective = "Sepultura 05 — descubra por que a pedra anuncia a morte de Ana num ano futuro.",
        evidence = { "book:05", "carta_tomas", "comprovante_ana" },
        hint = "É 1845: o ano na pedra é impossível, e o livro repete o erro. Procure um enterro registrado fora do livro, no arquivo da cripta.",
        proof = {
            accept = { "c4_comprovante" },
            feedback = {
                c4_lapide = "\"É justamente o que precisa de explicação.\"",
                c4_livro = "\"O livro também mente. Ele já sabe de um ano que ninguém viveu.\"",
                c4_tomas = "\"Tomás me amava, mas o amor não data o enterro.\"",
            },
        },
        fix = {
            title = "Corrigir a lápide",
            prompt = "ANA BEATRIZ DE ALMEIDA\nProfessora de primeiras letras\nFaleceu em ____",
            options = { "1844", "1845", "1846" },
            correct = 1,
            feedback = {
                [2] = "É o ano de agora, não o do enterro. O comprovante diz 1844.",
                [3] = "O 6 é o sulco novo, a mentira. Você não vai repeti-la.",
            },
        },
        question = "Por que a lápide de Ana Beatriz diz 1846?",
        hypotheses = {
            { text = "A pedra prevê uma morte em 1846.",
              feedback = "\"Ninguém morre num ano que ainda não nasceu.\"" },
            { text = "Ana nunca foi enterrada.",
              feedback = "\"O recibo guarda a data da terra sobre mim.\"" },
            { text = "A data foi reescrita para um ano que ainda não chegou.", correct = true },
        },
        resolution = "Você corrige para 1844. O 6 perde o brilho de pedra recém-cortada.\n\nO sino toca fora de hora. Na mesa, ao fundo, uma pena risca o livro sozinha.",
        newInscription = "ANA BEATRIZ DE ALMEIDA\nProfessora de primeiras letras\nFaleceu em 1844",
        summary = "Sepultura 05: a data de Ana Beatriz foi reescrita para um ano que ainda não chegou; ela morreu em 1844.",
    },
    {
        id = "c5", night = 3, grave = 1,
        title = "O nome raspado",
        objective = "Sepultura 01 — descubra quem foi sepultado na primeira cova.",
        evidence = { "book:01", "pagina_rasgada", "testemunho_vigario" },
        hint = "A página rasgada indica onde procurar, mas as iniciais não bastam. O testemunho do padre, no arquivo da cripta, dá o nome por inteiro.",
        proof = {
            accept = { "c5_padre" },
            feedback = {
                c5_raspado = "\"Raspar é fácil. Quero saber de quem era o nome.\"",
                c5_iniciais = "\"B. R. eram só duas letras. Precisas de alguém que me tenha visto.\"",
                c5_sumir = "\"Eu disse onde procurar. Não disse quem ia achar.\"",
                c5_silencio = "\"O padre se calou, sim. Mas sobre quem?\"",
            },
        },
        fix = {
            title = "Completar o registro",
            prompt = "Sepultura 01 — ____",
            options = { "Sepultura desconhecida", "Benedito Ramos — 1844", "José de Santana — 1844" },
            correct = 2,
            feedback = {
                [1] = "Seria escrever exatamente o que a Câmara queria: mais uma cova sem nome.",
                [3] = "O José da febre está na vala do fundo. Esta cova tem outro dono.",
            },
        },
        question = "Quem repousa na primeira cova?",
        hypotheses = {
            { text = "A primeira cova guarda Benedito Ramos, o antigo coveiro.", correct = true },
            { text = "A primeira cova é de um morto da febre, sem identidade.",
              feedback = "\"Eu nomeava os outros. O meu foi o primeiro que levaram.\"" },
            { text = "A cova pertence ao escrivão invisível.",
              feedback = "\"Quem escreve ainda está em pé.\"" },
        },
        resolution = "Você grava: Benedito Ramos, 1844.\n\nAs velas do caminho apagam uma a uma. Por um instante, o cemitério fica sem som. Então uma luz fria cai sobre a lápide lisa, a 06.",
        newInscription = "BENEDITO RAMOS\nZelador e coveiro\nFaleceu em 1844\n\"Escreveu o que viu.\"",
        summary = "Sepultura 01: Benedito Ramos, o antigo coveiro, recusou-se a falsificar os mortos da febre e foi enterrado sem nome.",
    },
    {
        id = "c6", night = 3, grave = 6, requires = "c5",
        title = "A lápide lisa",
        objective = "Sepultura 06 — decida o destino do livro e das memórias da vila.",
        evidence = { "book:06", "oficio_camara" },
        hint = "Não há resposta certa aqui. Leia a última página do livro e a ordem da Câmara, na cripta; depois encare o escrivão ao lado da lápide lisa.",
        question = "O livro guarda uma versão da vila. O que você fará com ele?",
        decision = true,
        hypotheses = {
            { text = "Preservar o livro: uma história coerente, mesmo incompleta.", ending = "preserve" },
            { text = "Revelar a verdade: entregar o livro e a ordem da Câmara à vila.", ending = "reveal" },
            { text = "Ainda não. Quero rever os documentos.", back = true },
        },
        summary = "Sepultura 06: a última página traz o seu nome.",
    },
}

----------------------------------------------------------------------
-- Noites
-- subtitle aparece na barra de cima ("Noite 1/3 — ..."): manter curto.
----------------------------------------------------------------------
N.nights = {
    {
        title = "Noite 1",
        subtitle = "O primeiro nome",
        intro = "\"Uma pedra não pode mentir. Pode?\"\n\nDois registros não combinam com suas sepulturas. Severino resolve começar pelo que está diante dos olhos.\n\nComo jogar: ande com W A S D e olhe com o mouse; mire numa sepultura e aperte E. Leia a lápide e os documentos e anote no caderno os detalhes que importam; alguns papéis não estão na cova, e sim espalhados pelo cemitério, brilhando no escuro. Fale com o morto: escolha uma conclusão e apresente a anotação que a prova. Depois, escolha a correção e grave-a na pedra com a sua própria mão: segure E diante da lápide. O Tab abre o caderno sem pausar.",
        outro = "A lamparina da mesa se apaga e volta a acender.\n\nA lápide 03, de Joaquina de Jesus, agora diz: \"Viu o zelador sair com o livro.\" Entre as últimas folhas do livro, há uma página rasgada: \"Não escrevo mais o que me mandam. Se eu sumir, procurem na primeira cova. — B. R.\"\n\n— Severino pensa: \"Não são só os mortos que mudam de nome. Quem escreveu esta página ainda está aqui.\"",
    },
    {
        title = "Noite 2",
        subtitle = "As histórias trocadas",
        intro = "\"Dois homens, um nome. Uma morte, dois anos.\"\n\nA página rasgada não explica a mão invisível. Um vulto, porém, deixa três sussurros pelo caminho: a mesa, o chão da quarta cova e a porta da cripta.\n\nNem todo papel fica junto da cova. Quando a sepultura pedir um documento que não está ali, procure o brilho de papel pelo cemitério.",
        outro = "No arquivo da Câmara, aparece um papel do Padre Inácio que não estava lá antes. A última linha ainda está fresca:\n\n\"Benedito Ramos. Era ele quem guardava este livro. Recusei-me a falar quando pediram silêncio.\"\n\n— Severino pensa: \"O padre sabia. Se o nome apareceu só agora, quantas outras linhas esperam ser lembradas?\"",
    },
    {
        title = "Noite 3",
        subtitle = "O nome que falta",
        intro = "\"A primeira cova espera.\"\n\nO vulto deixa de fugir. Entre a mesa e a primeira cova, velas acendem uma a uma, sem que ninguém as toque.",
    },
}

-- Eventos aplicados ao fim de cada noite (mudanças de memória)
N.nightEvents = {
    [1] = { flags = { "night1_event" },
            inscriptions = { [3] = "JOAQUINA DE JESUS\nRendeira\nFaleceu em 1844\n\"Viu o zelador sair com o livro.\"" },
            note = "Sepultura 03: a inscrição de Joaquina de Jesus mudou sozinha. Uma página rasgada, assinada B. R., apareceu no livro." },
    [2] = { flags = { "night2_event" },
            note = "Um testemunho do Padre Inácio apareceu no arquivo da Câmara. Ele fala de Benedito Ramos, o antigo zelador." },
}

----------------------------------------------------------------------
-- Finais
----------------------------------------------------------------------
N.endings = {
    preserve = {
        title = "Preservar o livro",
        pages = {
            "Severino fecha o livro. O escrivão recolhe a pena, satisfeito.\n\nA febre de 1844 continua espalhada por datas diferentes. Os mortos guardam alguns nomes nas pedras corrigidas, mas a vila não conhecerá o número verdadeiro de ausentes.\n\nAo longe, um sino soa uma vez.",
            "Dias depois, na última página, a tinta seca sob um nome novo: \"Severino Lopes, coveiro. Sepultado em 25 de novembro de 1845.\"\n\nNão há testemunha do que ocorreu entre a assinatura e a terra. Sob a luz fraca, Benedito sussurra: \"Um livro em paz não é o mesmo que um morto em paz.\"",
        },
    },
    reveal = {
        title = "Revelar a verdade",
        pages = {
            "Severino abre o livro na página da febre. Em vez de repartir os mortos entre estações, escreve o que os papéis dispersos confirmam: 1844, muitos nomes, uma só calamidade.\n\nO escrivão tenta continuar a frase oficial, mas a pena deixa de riscar o papel.",
            "A linha reservada para Severino perde a data. No cemitério, as pedras já não precisam responder ao livro.\n\nA vila acordará lembrando os que não tiveram cruz, ainda que não saiba o que fazer com a lembrança. Benedito se despede: \"Não devolveste a vida. Devolveste o direito de serem chorados.\"",
        },
    },
    mistakesNote = "\n\n(Algumas correções erradas também ficaram no livro. A memória da vila carrega as suas dúvidas.)",
}

----------------------------------------------------------------------
-- Telas fixas
----------------------------------------------------------------------
N.menu = {
    title = "O Coveiro de 1845",
    subtitle = "Os Nomes Esquecidos",
    body = "Vila de Santa Luzia do Paramopama, Sergipe, novembro de 1845.\n\nVocê é Severino Lopes, o novo coveiro. O livro de registros não concorda com as cartas da vila, e as lápides mudam quando ninguém está olhando.\n\nQuem decide o que a cidade lembra dos seus mortos?",
}

N.controls = "W A S D (ou setas): andar   ·   Shift: correr   ·   Mouse: olhar\nE ou clique: examinar, pegar papéis e falar com os mortos sob a mira\nSegurar E diante da lápide: gravar a correção com o cinzel\nTab: caderno (sem pausar)   ·   L: livro de registros   ·   H: ajuda (sem penalidade)\nE ou Esc: fecha o painel aberto   ·   Esc: pausa o jogo\n\nControls (EN): WASD to walk, Shift to run, mouse to look. E or click to inspect, pick up papers and talk to the dead. Hold E at a gravestone to carve the correction. Tab toggles the notebook without pausing, L opens the record book, H gives a hint, E or Esc closes panels, Esc pauses. Game text is in Portuguese."

N.credits = "O Coveiro de 1845: Os Nomes Esquecidos\nDoriax Flash Jam 2026\n\nModelos 3D: KayKit por Kay Lousberg — Halloween Bits, Dungeon Pack e RPG Tools Bits (CC0).\nFonte: Roboto (Google, Apache 2.0), fonte padrão do Doriax.\nMotor: Doriax Engine.\nCódigo e textos produzidos com auxílio de IA (Claude).\n\nTodas as pessoas, lugares e acontecimentos são ficcionais, inspirados no Sergipe da década de 1840."

----------------------------------------------------------------------
-- Prólogo (antes da Noite 1)
----------------------------------------------------------------------
N.prologue = {
    { title = "Santa Luzia do Paramopama", subtitle = "Sergipe, 1845",
      body = "Santa Luzia do Paramopama vivia do rio.\n\nEm 1844, quando a febre visitou suas casas, os sinos tocaram menos do que as famílias choraram. A Câmara chamou aquilo de prudência." },
    { title = "A nomeação", subtitle = "Ofício da Câmara Municipal", paper = "record",
      body = "\"Por ordem da Câmara Municipal, Severino Lopes assume o ofício de coveiro e zelador do campo-santo.\"\n\nO lugar estava vago. O nome do antigo responsável não constava no ofício." },
    { title = "O portão", subtitle = "17 de novembro de 1845",
      body = "Uma lamparina ardia ao fundo do cemitério. Sobre a mesa, um livro estava aberto.\n\nSeverino ouviu o raspar de uma pena — e não viu mão alguma." },
}

----------------------------------------------------------------------
-- Pensamentos de Severino ao ler um documento pela primeira vez
----------------------------------------------------------------------
N.thoughts = {
    ["oficio_nomeacao"] = "Um espaço em branco onde devia estar o nome de quem veio antes de mim.",
    ["book:07"] = "O livro e a pedra concordam. Concordam demais.",
    ["bilhete_rosa"] = "Ela lembra do pai vivo, mas não sabe dizer quando.",
    ["assento_antonio"] = "1845. Um papel da paróquia, fora do alcance do livro.",
    ["book:02"] = "Nem dia, nem mês. Alguém teve pressa de esquecer.",
    ["bilhete_firmino"] = "Um canteiro que não pôde gravar o nome da própria mulher.",
    ["extrato_paroquial"] = "Nunes antes do casamento, Santos depois. E morta em 1844, na febre.",
    ["book:04"] = "Uma linha só para dois homens. A Câmara contava menos mortos do que havia.",
    ["folha_irmandade"] = "Dois Josés. Um na cova, outro na vala, sem cruz.",
    ["book:05"] = "O livro já conhece um ano que ainda não chegou.",
    ["carta_tomas"] = "Meses depois do enterro. Ele não diz o ano, mas diz o bastante.",
    ["comprovante_ana"] = "1844. A paróquia guardou o que o livro tentou apagar.",
    ["book:01"] = "Rasparam o nome do papel também, não só da pedra.",
    ["pagina_rasgada"] = "\"Procurem na primeira cova.\" Ele sabia o que ia acontecer.",
    ["testemunho_vigario"] = "O padre enterrou um homem e aceitou esquecer o nome dele.",
    ["book:06"] = "Vinte e cinco de novembro. Daqui a oito dias.",
    ["oficio_camara"] = "Primeiro trocaram datas. Depois misturaram nomes. Agora há uma linha reservada para mim.",
}

-- Pensamento ao começar cada caso
N.caseThoughts = {
    c1 = "Antônio Ferreira, mestre de saveiro. A pedra e o livro concordam no ano. Por que isso me incomoda?",
    c2 = "Maria Nunes. Só isso. Nenhuma lavadeira tinha um nome tão curto.",
    c3 = "José de Santana, carpinteiro. Mas é o sino que eu ouço perto desta cova.",
    c4 = "Ana Beatriz morreu num ano que ainda não chegou. Alguém mexeu nessa pedra.",
    c5 = "A primeira cova. A página rasgada mandou procurar aqui.",
    c6 = "A última pedra está lisa. O livro, não. E há alguém escrevendo nele.",
}

----------------------------------------------------------------------
-- Sussurros: legendas disparadas ao chegar perto de um lugar (uma vez por campanha)
-- x/z = posição no cemitério; night = noite mínima; flag = evento necessário
----------------------------------------------------------------------
N.whispers = {
    { id = "gate", x = 0, z = 14.5, radius = 4, night = 1, speaker = "Severino",
      text = "O portão rangeu atrás de mim. Ninguém o empurrou." },
    { id = "desk", x = 6, z = -16, radius = 4, night = 1, speaker = "Severino",
      text = "O livro está aberto numa página que eu não abri." },
    { id = "crypt", x = -11, z = -13.5, radius = 5, night = 1, speaker = "Severino",
      text = "Do arquivo vem cheiro de cera velha. A Câmara guarda aqui o que não quer ver." },
    { id = "grave03", x = 5, z = -6.5, radius = 3.5, night = 2, flag = "night1_event", speaker = "Severino",
      text = "Joaquina viu o zelador com o livro. Tentava escondê-lo, ou levá-lo a alguém?" },
    { id = "bell", x = -2.2, z = -2, radius = 4, night = 2, speaker = "Severino",
      text = "Um sino, uma vez só. A Matriz fica a meia légua daqui." },
    { id = "grave01", x = -12, z = -6.5, radius = 4, night = 2, flag = "night2_event", speaker = "Sussurro",
      text = "...a primeira cova não tem nome porque não deixaram..." },
    { id = "grave06", x = -4.5, z = 5.5, radius = 3.5, night = 3, speaker = "Severino",
      text = "Uma pedra lisa. Como se estivesse esperando alguém." },
    { id = "road", x = 0, z = 15, radius = 4.5, night = 3, speaker = "Sussurro",
      text = "...vinte e cinco de novembro... vinte e cinco..." },
}

N.toasts = {
    notCaseGrave = "Esta sepultura não faz parte do caso desta noite.",
    resolvedGrave = "Registro já corrigido.",
    crypt = "O arquivo da Câmara. Lá dentro, só caixas de papéis úmidos e o cheiro de cera velha.",
    idleHint = "Precisa de uma pista? Clique em Ajuda.",
    lockedGrave = "A pedra lisa ainda não diz nada. Primeiro, a primeira cova.",
}

return N
