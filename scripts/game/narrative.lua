-- NarrativeData: todo o texto do jogo. Pessoas, lugares e acontecimentos são ficcionais.
-- A lógica (game/flow.lua) e a interface (hud_controller.lua) apenas leem esta tabela.

local N = {}

N.protagonist = "Severino Lopes"
N.town = "Vila de Santa Luzia do Paramopama"
N.nightCount = 3

----------------------------------------------------------------------
-- Sepulturas (7 no cenário; a 03 não pertence a nenhum caso)
----------------------------------------------------------------------
N.graves = {
    [1] = { number = "01", entity = "Grave01", name = "Sepultura sem nome",
            inscription = "AQUI JAZ\n(o nome foi raspado da pedra)\nFaleceu em 1844" },
    [2] = { number = "02", entity = "Grave02", name = "Maria das Dores",
            inscription = "MARIA DAS DORES SANTOS\nLavadeira do Paramopama\nFaleceu em 1845" },
    [3] = { number = "03", entity = "Grave03", name = "Joaquina de Jesus",
            inscription = "JOAQUINA DE JESUS\nRendeira\nFaleceu em 1844" },
    [4] = { number = "04", entity = "Grave04", name = "José de Santana",
            inscription = "JOSÉ DE SANTANA\nTocou o sino da Matriz por quarenta anos\nFaleceu em 1844" },
    [5] = { number = "05", entity = "Grave05", name = "Ana Beatriz de Almeida",
            inscription = "ANA BEATRIZ DE ALMEIDA\nProfessora de primeiras letras\nFaleceu em 1846" },
    [6] = { number = "06", entity = "Grave06", name = "Lápide lisa",
            inscription = "(A pedra está lisa. Nenhum nome, nenhuma data.)" },
    [7] = { number = "07", entity = "Grave07", name = "Antônio Ferreira",
            inscription = "ANTÔNIO FERREIRA\nMestre do saveiro Bom Jesus\nFaleceu em 1843" },
}

----------------------------------------------------------------------
-- Documentos (livro de registros e papéis avulsos)
-- kind: "book" (entrada do livro) | "letter" | "testimony" | "record"
-- variants: textos que substituem/complementam o corpo quando uma flag é ativada
----------------------------------------------------------------------
N.evidence = {
    ["book:07"] = { kind = "book", title = "Livro de registros — nº 07",
        body = "Registro nº 07 — Antônio Ferreira, 52 anos, mestre do saveiro Bom Jesus. Falecido de febre em 3 de março de 1845. Sepultado no mesmo dia.\n\nAo pé da linha: \"Lançado por ordem da Câmara.\"" },
    ["carta_rosa"] = { kind = "letter", title = "Carta de Rosa Ferreira",
        subtitle = "Estância, 20 de junho de 1844",
        body = "\"Meu pai, recebi as redes que o senhor mandou no Bom Jesus em maio. Mãe diz que o senhor tosse demais e que é para largar o sal das velas antes da chuva. Mande notícias pelo próximo saveiro.\n\nSua filha, Rosa Ferreira.\"" },

    ["book:02"] = { kind = "book", title = "Livro de registros — nº 02",
        body = "Registro nº 02 — Maria das Dores Nunes, 34 anos, lavadeira. Sepultada em 12 de agosto de 1845.\n\nÀ margem, em outra tinta: \"Não confundir com M. das Dores Santos — sem registro de óbito.\"" },
    ["assento_casamento"] = { kind = "record", title = "Assento de casamento",
        subtitle = "Livro de casamentos da Matriz, 1840",
        body = "\"Aos nove dias de maio de 1840, recebem-se em matrimônio Firmino dos Santos e Maria das Dores Nunes, lavadeira, que daqui em diante passa a assinar Maria das Dores Santos.\"\n\nAssina o Padre Inácio." },

    ["book:04"] = { kind = "book", title = "Livro de registros — nº 04",
        body = "Duas linhas para o mesmo número, na mesma letra:\n\n• José de Santana, 61 anos, sineiro. Sepultado em 9 de abril de 1844.\n• José de Santana, 27 anos, carpinteiro. Sepultado em 9 de abril de 1844." },
    ["testemunho_vigario"] = { kind = "testimony", title = "Testemunho do Padre Inácio",
        subtitle = "Escrito em abril de 1844",
        body = "\"Enterrei o velho José com a corda do sino nas mãos, como ele pediu. O moço carpinteiro, do mesmo nome, foi levado junto com os outros da febre para a vala do fundo, sem cruz.\"",
        variants = {
            { flag = "night2_event", append = "\n\nUma frase nova surgiu ao pé da página, na mesma letra:\n\"Quem lançava os mortos da febre era Benedito Ramos, o zelador. Dizia que a Câmara mandava escrever menos. Depois do São João, ninguém o viu mais.\"" },
        } },
    ["inventario_04"] = { kind = "record", title = "Inventário da sepultura 04",
        subtitle = "Reforma do muro, 1845",
        body = "Objetos achados ao reabrir a sepultura 04:\n\n• um pedaço de corda de sino, trançada;\n• um rosário de contas pretas;\n• nenhuma ferramenta." },

    ["book:05"] = { kind = "book", title = "Livro de registros — nº 05",
        body = "Registro nº 05 — Ana Beatriz de Almeida, 29 anos, professora de primeiras letras. Falecida em 2 de setembro de 1845, sepultada no dia seguinte." },
    ["carta_tomas"] = { kind = "letter", title = "Carta de Tomás de Almeida",
        subtitle = "4 de setembro de 1845",
        body = "\"Meu tio, enterramos Ana ontem, ao lado da cova do sineiro. Os alunos levaram flores de algodão. Não sei como contar à mãe.\"" },
    ["bilhete_canteiro"] = { kind = "letter", title = "Bilhete do canteiro Firmino",
        subtitle = "Preso à grade do portão",
        body = "\"Gravei 1845, como me pediram, e cobrei por isso. Se a pedra agora diz outra coisa, não foi a minha mão. Os sulcos do 6 são novos — qualquer um vê.\"" },

    ["book:01"] = { kind = "book", title = "Livro de registros — nº 01",
        body = "Registro nº 01 — a linha está em branco desde 1844.\n\nEsta noite, letra por letra, um nome aparece: \"Benedito Ramos, zelador e coveiro. Causa da morte: —\"\n\nO resto continua em branco." },
    ["pagina_rasgada"] = { kind = "letter", title = "Página rasgada",
        subtitle = "Presa entre as últimas folhas do livro",
        body = "\"...os mortos da febre não cabem no número que a Câmara quer. Mandam lançar com datas espalhadas, para o porto não fechar. Não escrevo mais o que me mandam. Se eu sumir, procurem na primeira cova.\"\n\n— B. R." },
    ["oficio_camara"] = { kind = "record", title = "Ofício da Câmara Municipal",
        subtitle = "Julho de 1844 — achado no arquivo da cripta",
        body = "\"Ordena-se ao zelador que os óbitos da febre sejam lançados com datas diversas e em números separados, para não alarmar o porto nem afastar os navios. O desobediente será dispensado, e seu nome, riscado.\"" },

    ["book:06"] = { kind = "book", title = "Livro de registros — última página",
        body = "Uma linha nova, na mesma letra de todos os registros:\n\n\"Registro nº 06 — Severino Lopes, coveiro. Sepultado em 25 de novembro de 1845.\"\n\nHoje é 17 de novembro de 1845." },
    ["nota_benedito"] = { kind = "letter", title = "Bilhete de Benedito Ramos",
        subtitle = "Dobrado dentro do ofício da Câmara",
        body = "\"O livro guarda a vila inteira. Quem o mantém em ordem acaba escrito nele. Para que uma história fique limpa, outra precisa ser esquecida.\n\nEu escolhi não esquecer. Agora é a sua vez de escolher.\"" },
}

----------------------------------------------------------------------
-- Casos (em ordem). evidence = documentos exigidos além da própria lápide.
----------------------------------------------------------------------
N.cases = {
    {
        id = "c1", night = 1, grave = 7,
        title = "Antônio Ferreira",
        objective = "Sepultura 07 — Antônio Ferreira: a data da lápide não confere com o livro.",
        evidence = { "book:07", "carta_rosa" },
        hint = "Compare as três datas: a lápide diz 1843, o livro diz 1845 e a carta da filha foi escrita em 1844. Quem está errado?",
        question = "O que os documentos sustentam sobre Antônio Ferreira?",
        hypotheses = {
            { text = "A lápide está errada: Antônio morreu em 1845, como diz o livro.", correct = true },
            { text = "O livro registra outro homem com o mesmo nome.",
              feedback = "Você folheia o ano inteiro: não há outro Antônio Ferreira. E a carta da filha fala do mesmo saveiro, o Bom Jesus." },
            { text = "Não há provas suficientes para corrigir nada.",
              feedback = "A carta de Rosa tem data — junho de 1844 — e fala do pai vivo. Um homem morto em 1843 não manda redes para a filha." },
        },
        resolution = "Você raspa o musgo e corrige a inscrição: 1845.\n\nPor um instante, ouve remos batendo n'água — longe demais do rio. Quando olha de novo, há velas acesas ao pé da cova, embora ninguém as tenha acendido.",
        newInscription = "ANTÔNIO FERREIRA\nMestre do saveiro Bom Jesus\nFaleceu em 1845",
        summary = "Sepultura 07: a lápide de Antônio Ferreira dizia 1843; ele morreu em 1845.",
    },
    {
        id = "c2", night = 1, grave = 2,
        title = "Maria das Dores",
        objective = "Sepultura 02 — Maria das Dores: o nome da lápide não é o nome do livro.",
        evidence = { "book:02", "assento_casamento" },
        hint = "O livro fala de Maria das Dores Nunes; a lápide, de Maria das Dores Santos. O assento de casamento explica por que um nome virou o outro.",
        question = "Como resolver a diferença entre os dois nomes?",
        hypotheses = {
            { text = "Há duas mulheres: o corpo foi enterrado na sepultura errada.",
              feedback = "Abrir uma cova por causa de um sobrenome? O assento de casamento explica a diferença sem tocar em ninguém." },
            { text = "É a mesma mulher: o livro deve ligar os dois nomes.", correct = true },
            { text = "A lápide foi feita para alguém que ainda está viva.",
              feedback = "Ninguém na vila viu Maria das Dores Santos desde agosto. O assento mostra que ela e a Nunes são a mesma pessoa." },
        },
        resolution = "Você escreve à margem: \"Nunes, depois Santos — a mesma.\"\n\nA nota em outra tinta escurece até sumir, como se alguém do outro lado do papel a apagasse. Na lápide, o nome agora aparece inteiro.",
        newInscription = "MARIA DAS DORES NUNES SANTOS\nLavadeira do Paramopama\nFaleceu em 1845",
        summary = "Sepultura 02: Maria das Dores Nunes e Maria das Dores Santos eram a mesma mulher.",
    },
    {
        id = "c3", night = 2, grave = 4,
        title = "José de Santana",
        objective = "Sepultura 04 — José de Santana: dois homens com o mesmo nome no mesmo número.",
        evidence = { "book:04", "testemunho_vigario", "inventario_04" },
        hint = "Um José era sineiro, o outro carpinteiro. O que foi encontrado dentro da cova 04? E para onde o padre diz que levaram o moço?",
        question = "Quem está, de fato, na sepultura 04?",
        hypotheses = {
            { text = "Os dois Josés foram enterrados na mesma cova.",
              feedback = "O inventário achou uma só corda de sino e nenhuma ferramenta. E o padre diz que o moço foi para a vala do fundo." },
            { text = "A cova 04 é do sineiro; o carpinteiro foi lançado no número errado.", correct = true },
            { text = "A cova é do carpinteiro; a lápide mente sobre o sino.",
              feedback = "Um carpinteiro de 27 anos não levaria uma corda de sino trançada nas mãos. O testemunho e o inventário apontam para o sineiro." },
        },
        resolution = "Você risca a segunda linha e escreve: \"José de Santana, carpinteiro — vala da febre, sem cruz.\"\n\nDo fundo do cemitério vem um som curto de sino, uma vez só. A vila nunca contou quantos foram para aquela vala.",
        summary = "Sepultura 04: é do sineiro. O carpinteiro de mesmo nome foi para a vala da febre, sem cruz.",
    },
    {
        id = "c4", night = 2, grave = 5,
        title = "Ana Beatriz de Almeida",
        objective = "Sepultura 05 — Ana Beatriz: a lápide marca um ano que ainda não chegou.",
        evidence = { "book:05", "carta_tomas", "bilhete_canteiro" },
        hint = "O livro e a carta do irmão concordam em 1845. O canteiro jura que gravou 1845. Então quem mudou o 6 — e quando?",
        question = "Por que a lápide de Ana Beatriz diz 1846?",
        hypotheses = {
            { text = "O canteiro errou a data ao gravar a pedra.",
              feedback = "Firmino diz que gravou 1845 e aponta os sulcos novos do 6. O erro não estava na mão dele." },
            { text = "Ana ainda vive; o enterro foi encenado.",
              feedback = "O irmão escreveu no dia seguinte ao enterro. Ninguém encena um enterro para a vila inteira e conta isso à própria família." },
            { text = "Alguém alterou a lápide de propósito, depois do enterro.", correct = true },
        },
        resolution = "Você passa os dedos pelo 6: a pedra ainda está áspera, recém-cortada. Corrige para 1845.\n\nEntão percebe: em outras páginas do livro, a tinta também está úmida. Alguém — ou alguma coisa — continua escrevendo depois de você.",
        newInscription = "ANA BEATRIZ DE ALMEIDA\nProfessora de primeiras letras\nFaleceu em 1845",
        summary = "Sepultura 05: a data de Ana Beatriz foi alterada de propósito, depois do enterro.",
    },
    {
        id = "c5", night = 3, grave = 1,
        title = "A primeira cova",
        objective = "Sepultura 01 — a cova sem nome: descubra o que aconteceu com Benedito Ramos.",
        evidence = { "book:01", "pagina_rasgada", "oficio_camara" },
        hint = "Releia a página rasgada com as iniciais B. R. e o ofício da Câmara. O que acontecia com quem desobedecia?",
        question = "Por que Benedito Ramos desapareceu dos registros?",
        hypotheses = {
            { text = "Benedito fugiu da vila levando o arquivo.",
              feedback = "O arquivo continua na cripta, com o ofício dentro. E a página rasgada diz onde procurá-lo: na primeira cova." },
            { text = "Benedito morreu da febre e ninguém o registrou, por descuido.",
              feedback = "Descuido não raspa um nome da pedra. O ofício promete riscar o nome do desobediente — e foi o que fizeram." },
            { text = "Benedito se recusou a falsificar os registros e foi apagado.", correct = true },
        },
        resolution = "Você completa a linha: \"Benedito Ramos — recusou-se a escrever o que mandavam.\"\n\nA pedra da sepultura 01 range. O nome reaparece sob a raspagem, fundo, como se nunca tivesse saído dali.",
        newInscription = "BENEDITO RAMOS\nZelador e coveiro\nFaleceu em 1844\n\"Escreveu o que viu.\"",
        summary = "Sepultura 01: Benedito Ramos recusou-se a falsificar os mortos da febre e teve o nome apagado.",
    },
    {
        id = "c6", night = 3, grave = 6,
        title = "O nome que falta",
        objective = "Sepultura 06 — a lápide lisa. Leia a última página do livro.",
        evidence = { "book:06", "nota_benedito" },
        hint = "Não há resposta certa aqui. Leia a última página e o bilhete de Benedito, e decida o que a vila deve lembrar.",
        question = "O livro guarda uma versão da vila. O que você fará com ele?",
        decision = true,
        hypotheses = {
            { text = "Preservar o livro: uma história coerente, mesmo incompleta.", ending = "preserve" },
            { text = "Revelar a verdade: entregar o livro e o ofício à vila.", ending = "reveal" },
            { text = "Ainda não. Quero rever os documentos.", back = true },
        },
        summary = "Sepultura 06: a última página traz o seu nome.",
    },
}

----------------------------------------------------------------------
-- Noites
----------------------------------------------------------------------
N.nights = {
    {
        title = "Noite 1",
        subtitle = "O primeiro nome",
        intro = "Seu primeiro turno no cemitério. O livro de registros está aberto na mesa, ao fundo. Algumas lápides não batem com o que está escrito nele.\n\nComo jogar: clique na sepultura marcada pela luz fria para examiná-la. Consulte o livro e os documentos e, quando tiver lido todas as fontes, use \"Confrontar registros\" para decidir o que as provas sustentam.",
        outro = "Ao fechar o livro, você nota que a inscrição da sepultura 03 mudou. Ninguém passou pelo portão.\n\nEntre as últimas folhas, há uma página rasgada assinada com as iniciais B. R. — Benedito Ramos, o coveiro antes de você.",
    },
    {
        title = "Noite 2",
        subtitle = "As histórias trocadas",
        intro = "Esta noite, dois registros parecem contar a história errada — e um deles, de propósito.",
        outro = "Ao reler o testemunho do Padre Inácio, você encontra uma frase que não estava lá antes. Ela fala de Benedito Ramos, o antigo zelador, e de mortos que a Câmara mandava esconder.\n\nA primeira cova, a 01, nunca teve nome.",
    },
    {
        title = "Noite 3",
        subtitle = "O nome que falta",
        intro = "A primeira cova espera um nome. A última também.",
    },
}

-- Eventos aplicados ao fim de cada noite (mudanças de memória)
N.nightEvents = {
    [1] = { flags = { "night1_event" },
            inscriptions = { [3] = "JOAQUINA DE JESUS\nRendeira\nFaleceu em 1844\n\"Viu o zelador sair com o livro.\"" },
            note = "Sepultura 03: a inscrição de Joaquina de Jesus mudou sozinha. Uma página rasgada apareceu no livro." },
    [2] = { flags = { "night2_event" },
            note = "O testemunho do Padre Inácio ganhou uma frase nova sobre Benedito Ramos." },
}

----------------------------------------------------------------------
-- Finais
----------------------------------------------------------------------
N.endings = {
    preserve = {
        title = "Preservar o livro",
        pages = {
            "Você costura a página rasgada de volta, apaga as margens corrigidas e devolve o livro à mesa.\n\nPela manhã, a vila acorda com uma história limpa: poucos mortos, datas em ordem, nenhum zelador desaparecido.",
            "A lápide 06 continua lisa. Toda noite você confere os nomes, e toda noite um deles é um pouco menos verdadeiro.\n\nNo dia 25 de novembro, ninguém estranha que o coveiro não apareça. O livro já sabia.\n\nA cidade lembra de forma coerente. Só não lembra de tudo.",
        },
    },
    reveal = {
        title = "Revelar a verdade",
        pages = {
            "Você leva o livro, a página de Benedito e o ofício da Câmara até a porta da Matriz.\n\nEm poucos dias, a vila discute nomes que não queria ouvir: a febre, a vala sem cruz, Benedito Ramos.",
            "As lembranças agora se contradizem — e por isso pertencem a muitas pessoas, não a um só livro.\n\nA linha com o seu nome desbota até virar uma mancha de tinta. Você será lembrado de outro jeito: como o coveiro que deixou os mortos discordarem.",
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
    body = "Vila de Santa Luzia do Paramopama, Sergipe, novembro de 1845.\n\nVocê é Severino Lopes, o novo coveiro. O livro de registros não concorda com as lápides, e as cartas da vila não concordam com nenhum dos dois.\n\nQuem decide o que a cidade lembra dos seus mortos?",
}

N.controls = "Mouse: clique nas sepulturas e no livro sobre a mesa para examiná-los.\nLivro (canto superior direito): registros do caso atual e anotações.\nAjuda: aponta a fonte que ainda falta consultar, sem penalidade.\nESC: fecha o painel aberto ou pausa o jogo.\n\nControls (EN): click the graves and the record book to inspect them. \"Livro\" opens the records and notes, \"Ajuda\" gives a hint, ESC closes panels or pauses. Game text is in Portuguese."

N.credits = "O Coveiro de 1845: Os Nomes Esquecidos\nDoriax Flash Jam 2026\n\nModelos 3D: KayKit por Kay Lousberg — Halloween Bits, Dungeon Pack e RPG Tools Bits (CC0).\nFonte: Roboto (Google, Apache 2.0), fonte padrão do Doriax.\nMotor: Doriax Engine.\nCódigo e textos produzidos com auxílio de IA (Claude).\n\nTodas as pessoas, lugares e acontecimentos são ficcionais, inspirados no Sergipe da década de 1840."

N.toasts = {
    notCaseGrave = "Esta sepultura não faz parte do caso desta noite.",
    resolvedGrave = "Registro já corrigido.",
    crypt = "O arquivo da Câmara. Lá dentro, só caixas de papéis úmidos e o cheiro de cera velha.",
    idleHint = "Precisa de uma pista? Clique em Ajuda.",
}

return N
