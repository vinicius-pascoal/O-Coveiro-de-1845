# O Coveiro de 1845: Os Nomes Esquecidos
**GDD v1.0 — Doriax Flash Jam 2026**  
**Data-base:** 17/11/2026  
**Prazo de submissão:** 25/11/2026, 23h59 (Brasília, UTC-3)

## 1. High concept
Em 1845, em um cemitério de uma cidade fictícia inspirada em São Cristóvão, Sergipe, um novo coveiro encontra inconsistências entre os nomes das lápides, os registros de sepultamento e cartas antigas. A cada correção, um detalhe da memória da cidade se modifica. Ao longo de três noites, o jogador deve reconstruir seis registros e descobrir por que seu nome aparece no livro dos mortos.

**Gancho:** *Quem decide o que a cidade lembra dos seus mortos?*

**Gênero:** investigação, puzzle narrativo e terror atmosférico leve.  
**Perspectiva:** cenário 3D low-poly com câmera fixa inclinada; interação por clique.  
**Plataforma-alvo:** navegador desktop (HTML5/WebAssembly); fallback executável Windows.  
**Controle:** mouse (clique para inspecionar/selecionar), ESC para fechar painéis.  
**Duração-alvo:** 15 a 25 minutos.  
**Idioma:** português; página itch.io e controles resumidos também em inglês.  
**Motor:** Doriax Engine; lógica prioritariamente Lua; desenvolvimento com editor visual.

### Pilares
1. **Observar:** identificar detalhes contraditórios em lápides, documentos e testemunhos.
2. **Confrontar:** comparar pelo menos duas fontes independentes e assumir uma conclusão.
3. **Sentir as consequências:** decisões modificam textos, atmosfera e a interpretação do mistério.

## 2. Escopo fechado do MVP
- **Uma única área 3D:** cemitério murado com portão, seis sepulturas, pequena capela/arquivo externo e mesa de documentos. Não modelar cidade explorable.
- **Três noites lineares:** cada uma resolve dois casos curtos.
- **Seis sepulturas interativas**, um livro de registros, até seis cartas/relatos, poucas informações em tela por caso.
- **Um mistério central**, duas resoluções de encerramento, sem árvore de ramificações extensa.
- **Sem movimentação livre**, sem combate, sem inventário com slots, sem NPCs móveis, sem geração procedural, sem multiplayer.
- **Sem dublagem**; textos curtos, SFX ambientes e música discreta/licenciada.

### Fora de escopo
Salvamento persistente, física dinâmica complexa, falas ramificadas extensas, troca dinâmica de arquitetura, ciclo dia/noite real, física de escavação, editor de níveis, configurações gráficas avançadas, localização completa em inglês. Esses recursos só entram se a versão web final estiver pronta.

## 3. Mecânica principal — resolução de registros
A cada caso, o jogador seleciona uma sepultura. O painel exibe inscrição da lápide e número. Em seguida, ele pode consultar o livro no escritório e as pistas desbloqueadas. Um botão **Confrontar registros** abre três hipóteses curtas (por exemplo: 'a data da lápide foi adulterada', 'o registro do livro pertence a outra pessoa', 'não há provas suficientes').

**Regra de design:** cada caso tem uma conclusão demonstrável por evidências disponíveis, sem depender de tentativa e erro. Para concluir, o jogador deve abrir as pistas exigidas. Antes de confirmar, pode rever documentos livremente.

**Feedback:** acerto = registro marcado e pequena mudança sobrenatural; erro = feedback diegético e oportunidade de tentar novamente, com uma consequência narrativa simbólica (não bloquear a campanha). Em casos finais, escolhas morais alteram o epílogo, sem avaliar como 'correto/incorreto'.

**Sistema de ajuda:** após ~90 segundos de inatividade em um caso, opção 'Pedir pista' destaca a fonte ainda não consultada; sem penalidade.

**Loop:** receber o caso → examinar lápide → consultar livro/carta → confrontar → confirmar → observar mudança → próximo caso.

## 4. Roteiro das três noites
Todas as pessoas e acontecimentos abaixo são ficcionais.

### Noite 1 — O primeiro nome (tutorial e apresentação)
**Caso 01 — Antônio Ferreira / Sepultura 07:** lápide marca 1843, livro marca 1845, carta menciona Antônio vivo em 1844. Solução do puzzle: a inscrição de 1843 é inconsistente, e a data precisa ser corrigida à luz dos documentos.

**Caso 02 — Maria das Dores / Sepultura 02:** nome da lápide não coincide com uma segunda referência no livro; uma carta indica mudança de sobrenome. Solução: vincular os dois nomes à mesma pessoa, não trocar o corpo de sepultura.

**Evento da noite:** uma inscrição não envolvida nos casos muda discretamente. O livro apresenta uma página rasgada com referência ao antigo coveiro.

### Noite 2 — As histórias trocadas (conexões)
**Caso 03 — José de Santana / Sepultura 04:** os registros parecem apontar para duas pessoas de mesmo nome. O jogador cruza data e uma descrição de objeto pessoal para distinguir as entradas.

**Caso 04 — Ana Beatriz / Sepultura 05:** carta e livro concordam, mas a lápide apresenta uma data futura. A resolução revela que há alguém alterando registros propositalmente.

**Evento da noite:** um testemunho impresso muda depois de uma correção; os novos detalhes indicam o antigo zelador do cemitério.

### Noite 3 — O nome que falta (clímax)
**Caso 05 — Sepultura 01:** um registro aparentemente sem nome passa a exibir o do antigo coveiro; pistas da noite anterior determinam o motivo de seu desaparecimento.

**Caso 06 — Sepultura 06:** lápide vazia; ao abrir a última página, o jogador lê seu próprio nome, acompanhado de uma data que ainda não chegou. Não é uma pegadinha: a história revela que o cemitério preserva uma versão do passado à custa de apagar outra.

**Decisão final, sem pontuação:**
- **Preservar o livro:** a cidade continua lembrando uma história coerente, mas incompleta.
- **Revelar a verdade:** a cidade recupera memórias contraditórias e o coveiro aceita ser lembrado de maneira diferente.

**Epílogo:** 2 telas de texto, áudio e um detalhe visual alterado no cenário; evitar produzir duas cutscenes completas.

## 5. Mundo e mise-en-scène
**Distribuição do mapa:** entrada e portão (sul); cemitério com seis sepulturas em duas fileiras (centro); mesa de registros, capela simples ou pequena construção evocativa (norte); árvores e muros delimitam a área. Pistas sinalizadas por luminária suave e contorno/partículas discretas.

**Ambientação:** fantasia histórica inspirada em arquitetura colonial de Sergipe; sem afirmar que cenários ou eventos representam construções reais específicas.

**Arte:** low-poly KayKit, tons dessaturados, chão escuro, neblina leve, luz de lua fria e velas/lamparinas de cor quente. Não usar assets evidentemente anacrônicos (tratores, automóveis, abóboras de Halloween com rosto esculpido) na área histórica.

**Som:** vento, corujas/insetos, folhas, passos abstratos, folhear papel, clique seco de selo, sino e um efeito sutil de distorção nas mudanças de memória. Música ambiente opcional.

## 6. Interface e controles
### Tela de jogo
- Canto superior esquerdo: 'Noite 1/3' e objetivo curto.
- Canto superior direito: botões Livro, Ajuda e Pausa.
- Centro: cemitério 3D, lápides interativas com indicação discreta de hover.
- Painéis de inspeção: título da fonte, texto curto, botão Fechar e ação apropriada.
- Painel de resolução: mini-resumo de evidências consultadas, três hipóteses, Confirmar e Voltar.

### Regras de UX
- Sempre indicar visualmente o que pode ser clicado.
- Bloquear cliques no mundo quando um painel modal estiver aberto.
- Não esconder pistas essenciais em texto decorativo ou apenas em mudança de iluminação.
- Permitir consultar a qualquer momento um histórico das descobertas relevantes.
- Alto contraste e fonte legível; priorizar 1280×720, testar em 1920×1080 e janela menor.

## 7. Estrutura de dados proposta (conceitual)
**Grave:** id, modelEntity, personId, inscription, caseId, visualState.  
**Evidence:** id, caseId, kind (grave/book/letter/testimony), title, body, isUnlocked, isRead.  
**Case:** id, night, graveId, title, evidenceRequired[], hypotheses[], correctHypothesisId, postResolutionChange.  
**GameState:** currentNight, currentCase, openPanel, readEvidenceIds, resolvedCaseIds, endingChoice.

**Regra:** os dados de narrativa ficam em arquivos/módulos Lua separados da lógica, nunca duplicados na UI e na cena. Mudanças de memória trocam **textos e estados visuais definidos**, não geram mapas dinamicamente.

## 8. Organização técnica Doriax
- **World**: cena 3D com câmera, iluminação, lápides e `GameController`.
- **HUD**: cena UI sobreposta à World, com textos, botões e painéis.
- **MainMenu**: cena UI com Iniciar, Controles, Créditos.
- **Ending**: cena UI ou overlay final com duas variantes textuais.
- **Bundles**: opcional para instanciar sepulturas repetidas; priorizar referências estáveis e scene hierarchy simples.
- **Lua scripts**: `GameController`, `InteractionController`, `CaseService`, `EvidenceService`, `GraveController`, `UIController`, `AudioController`, `NarrativeData`.

### Interação 3D
Usar câmera `screenToRay` em clique de mouse e `Ray:intersects` com `RayFilter.BOUNDS` ou `RayFilter.BODY_3D` nos objetos interativos. Manter uma tabela explícita `entityId -> graveId/evidenceId` e privilegiar colisores simples nos pontos clicáveis. Validar esse fluxo antes de importar todo o cenário. Ao abrir uma UI modal, ignorar os cliques da cena 3D.

### Importação
O Doriax aceita FBX no editor e converte internamente para glTF/GLB. Copiar apenas assets selecionados e suas texturas do pacote, não a coleção inteira. Validar escala, materiais e orientação. Preferir uma build web cedo; preparar alternativa Desktop caso exportação Web falhe.

## 9. Critérios de aceite
- Um jogador entende controles e objetivo nos primeiros 60 segundos.
- Todos os seis casos podem ser resolvidos sem erros de estado ou telas travadas.
- O loop funciona sem movimento livre e sem dependências externas.
- Escolha final oferece dois epílogos distintos.
- Cena sempre permite consultar pistas e retornar à investigação.
- Projeto exporta e executa fora do editor (Web preferencial ou Windows fallback).
- Página itch.io possui versão jogável, controles, plataformas, créditos e explicação do tema.

## 10. Explicação do tema na página da jam
> O Coveiro de 1845 é um jogo de investigação sobrenatural situado em uma cidade fictícia inspirada no Sergipe oitocentista. Durante a década de 1840, registros de sepultamento e lápides começam a contradizer as lembranças dos habitantes. Ao comparar cartas incompletas, documentos e inscrições, o jogador decide quais histórias serão preservadas. O cenário — um cemitério que guarda as memórias da cidade — transforma o passado em uma mecânica de investigação e escolhas.

**Diretriz de publicação:** creditar KayKit, autores de músicas/sons/fontes e conteúdo criado com IA quando aplicável; confirmar permissões/licenças no pacote antes de publicar.

## 11. Referências técnicas
- https://docs.doriax.org/getting-started/first-project/
- https://docs.doriax.org/manual/creating-scripts/
- https://docs.doriax.org/manual/user-interface/
- https://docs.doriax.org/reference/classes/camera/
- https://docs.doriax.org/manual/physics/
- https://docs.doriax.org/editor/export/
- Fonte dos assets: `INVENTARIO_ASSETS_UNITY(1).md` fornecido pelo desenvolvedor.
