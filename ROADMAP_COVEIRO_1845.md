# Roadmap de desenvolvimento — O Coveiro de 1845
**Engine:** Doriax · **Linguagem:** Lua · **Janela da jam:** até 25/11/2026, 23h59 (UTC−3)

## Princípios de execução
1. **Jogabilidade primeiro:** cada fase termina com uma build executável em Play Mode.
2. **MVP fechado:** três noites, seis casos, câmera fixa, mouse, dois epílogos. Tudo além disso é opcional.
3. **Exportar antes de polir:** gerar build Web de uma cena mínima o mais cedo possível, não apenas na véspera.
4. **Plano B:** distribuir executável Windows se houver bloqueio de exportação Web; a jam aceita jogos para download.
5. **Limitar retrabalho:** não migrar de engine, não trocar arquitetura após a integração do primeiro caso.

## Fase 0 — Pré-voo técnico (17/11)
- [ ] Instalar uma versão estável/release do Doriax e verificar abertura do editor.
- [ ] Criar projeto vazio `o-coveiro-de-1845` em pasta versionada por Git.
- [ ] Salvar `scenes/world.scene` e `scenes/hud.scene` usando editor.
- [ ] Ajustar a resolução virtual para 1280×720 e escala apropriada à janela.
- [ ] Criar câmera fixa inclinada, sol/lua direcional e plano de chão com primitivas.
- [ ] Criar primeira entidade Lua e validar `init`/`onUpdate` no Play Mode.
- [ ] Importar 1 modelo FBX KayKit + textura e confirmar material/escala.
- [ ] Testar clique em um objeto com câmera `screenToRay` + raycast.
- [ ] Abrir o diálogo Export Project e testar um build Web da cena mínima.

**Aceite:** câmera, FBX, script Lua e um clique interativo funcionam; exportação tentada e problemas anotados.

## Fase 1 — Vertical slice do primeiro caso (18/11)
- [ ] Implementar `InteractionController` com clique sobre lápide.
- [ ] Criar `UIController` com modal de inspeção e modal do livro.
- [ ] Criar `NarrativeData` com dados do Caso 01.
- [ ] Criar `CaseService` que registra pistas abertas e avalia hipótese.
- [ ] Integrar transição de estado `Investigando -> Confirmando -> Resolvido`.
- [ ] Implementar pista opcional e botão de retorno/fechar.
- [ ] Verificar que UI modal impede clique acidental em cena.
- [ ] Exportar e executar vertical slice fora do editor.

**Aceite:** o jogador resolve Antônio Ferreira do início ao fim, sem usar o editor para intervir.

## Fase 2 — Cenário e identidade visual (19/11)
- [ ] Montar cemitério pequeno com solo, muro, portão, 6 lápides e cenário de fundo.
- [ ] Posicionar capela simbólica ou arquivo com mesa de registros.
- [ ] Implementar indicador de hover/seleção para objetos clicáveis.
- [ ] Configurar luz principal fria, luzes quentes localizadas e neblina sutil.
- [ ] Conferir câmera, legibilidade e oclusão das lápides.
- [ ] Restringir assets a alguns modelos úteis, sem importação em massa.

**Aceite:** cenário legível, objetos fáceis de encontrar e desempenho suficiente no navegador.

## Fase 3 — Noites 1 e 2 (20–21/11)
- [ ] Adicionar Caso 02, concluir roteiro e feedback da Noite 1.
- [ ] Implementar transição de noite simples (fade + texto), sem cutscene.
- [ ] Adicionar Casos 03 e 04 com mecanismos de comparação já existentes.
- [ ] Implantar mudanças da memória em páginas, cartas e uma inscrição.
- [ ] Testar fluxo de pistas, resolução incorreta e reabertura de painel.

**Aceite:** quatro casos concluídos e transição até a terceira noite sem quebra de estado.

## Fase 4 — Noite 3 e finais (22/11)
- [ ] Adicionar Casos 05 e 06 e revelar o nome do jogador no livro.
- [ ] Implementar decisão final e dois epílogos textuais.
- [ ] Adicionar menu inicial, reiniciar campanha, controles e créditos.
- [ ] Ajustar conteúdo para duração total de 15 a 25 minutos.

**Aceite:** início, meio e fim inteiramente jogáveis.

## Fase 5 — Atmosfera e acessibilidade (23/11)
- [ ] Inserir sons ambientais, página de livro, marcação e evento sobrenatural.
- [ ] Criar pequenos efeitos visuais nas alterações de memória.
- [ ] Revisar ortografia, tipografia e contraste.
- [ ] Ajustar pistas que não estejam claras.
- [ ] Corrigir problemas de navegação em telas de resolução inferior.
- [ ] Revisar créditos/licenças de todos os materiais usados.

**Aceite:** experiência compreensível e coesa, sem efeitos que prejudiquem a leitura.

## Fase 6 — Testes e publicação (24/11)
- [ ] Fazer pelo menos duas partidas completas sem reiniciar o aplicativo.
- [ ] Testar clique rápido, abrir/fechar UI, clique em objeto coberto, resolução errada, reinício, duas escolhas finais.
- [ ] Exportar build Web definitiva e testar em navegador diferente do usado no desenvolvimento.
- [ ] Se export Web falhar, gerar executável Windows e validar em outra máquina.
- [ ] Criar página itch.io: nome, capa/screenshot, descrição, controls, plataformas, créditos, theme interpretation.
- [ ] Publicar versão jogável e testar a página como visitante.

**Aceite:** build e página publicados; falta apenas submissão à jam.

## Fase 7 — Margem final (25/11)
- [ ] Corrigir somente bugs bloqueadores e erros de texto essenciais.
- [ ] Fazer backup da build válida e do código.
- [ ] Submeter o projeto pelo botão **Submit your project** na página da jam (publicar no perfil não basta).
- [ ] Confirmar que o jogo aparece na lista de entradas e que o link está jogável.
- [ ] Evitar enviar alterações nos últimos minutos.

**Aceite:** jogo confirmado entre as submissões antes de 23h59 (UTC−3).

## Dependências técnicas críticas
| Risco | Probabilidade | Mitigação |
|---|---|---|
| Falha de export Web / toolchain | Média | Exportar cena mínima no primeiro dia; manter fallback Desktop |
| FBX sem materiais ou escala incorreta | Média | Testar 1 modelo e texturas primeiro; usar apenas seleção curada |
| Raycast não identifica lápide | Média | Usar collider caixa simples ou hotspots UI como plano B |
| UI do Doriax consome tempo | Média | Criar um painel reutilizável com texto e botões |
| Narrativa maior do que o prazo | Alta | No máximo 6 casos e 2 epílogos curtos |
| Texto difícil de ler / interação confusa | Média | Teste de 60 s com pessoa que não conhece o projeto |

## Critérios de pronto ('definition of done')
- [ ] Jogável do menu aos créditos.
- [ ] Nenhum clique deixa o jogo sem saída.
- [ ] Seis casos resolvíveis com evidências corretas e feedback claro.
- [ ] Dois epílogos completos.
- [ ] Exportação fora do editor validada.
- [ ] Créditos e interpretação de '1840 and something' publicados.
- [ ] Submissão confirmada na jam.

## Tarefas delegáveis a um agente de desenvolvimento
**Lote A:** projeto Doriax, cenas vazias, import mínimo, raycast e prova de exportação.  
**Lote B:** modelos Lua `CaseService`/`EvidenceService`/`GameState` e caso 01, desacoplados da UI.  
**Lote C:** HUD, painel de registro, apresentação de cartas e botão de decisão.  
**Lote D:** integração dos seis casos, eventos por noite e finais.  
**Lote E:** testes manuais guiados, resolução de bugs, build e itch.io checklist.

**Regra para os lotes:** não iniciar o próximo antes de demonstrar o critério de aceite do anterior.
