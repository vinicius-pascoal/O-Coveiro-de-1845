# Mapa de assets selecionados — O Coveiro de 1845
Fonte: inventário `INVENTARIO_ASSETS_UNITY(1).md`, The Complete KayKit Collection v7.  
**Atenção:** o inventário identifica arquivos; ele não comprova que o conteúdo dos arquivos foi importado/testado. Copie os modelos necessários, texturas correspondentes e confirme visualmente no Doriax.

## Núcleo do cemitério
Diretório-base: `KayKit Halloween Bits 1.0/Assets/fbx(unity)/`

| Arquivo relativo | Uso sugerido |
|---|---|
| `grave_A.fbx` | Sepulturas variantes |
| `grave_B.fbx` | Sepulturas variantes |
| `gravestone.fbx` | Lápide principal interativa |
| `gravemarker_A.fbx` | Marcador secundário |
| `grave_A_destroyed.fbx` | Estado visual alterado |
| `floor_dirt_grave.fbx` | Solo da sepultura |
| `path_A.fbx` e `path_B.fbx` | Caminhos entre lápides |
| `fence.fbx`, `fence_gate.fbx` | Delimitação e portão |
| `wooden_gate.fbx` | Entrada |
| `lantern_standing.fbx`, `post_lantern.fbx` | Pontos de luz |
| `crypt.fbx` | Pequeno mausoléu/arquivo |
| `tree_dead_medium.fbx` | Silhueta atmosférica |
| `coffin.fbx` | Objeto de cenário opcional |

## Livro de registros e pistas
Diretório-base: `KayKit RPG Tools Bits 1.0/Assets/fbx(unity)/`

| Arquivo relativo | Uso sugerido |
|---|---|
| `journal_open.fbx`, `journal_closed.fbx` | Livro de registros |
| `magnifying_glass.fbx` | Símbolo de investigação / pista 3D |
| `key_A.fbx` | Chave encontrada (opcional) |
| `map.fbx` | Mapa antigo decorativo ou painel de pistas |
| `lantern.fbx` | Iluminação de mesa |
| `shovel.fbx` | Contexto do trabalho do protagonista |
| `pencil_A_long.fbx` | Mesa do coveiro |

## Mesa e arquivo
Diretório-base: `KayKit Dungeon Pack 1.1/Assets/fbx(unity)/`

| Arquivo relativo | Uso sugerido |
|---|---|
| `table_small.fbx` | Mesa de documentos |
| `chair.fbx` | Cadeira |
| `book_brown.fbx`, `book_grey.fbx` | Livros auxiliares |
| `bookcase_single.fbx` | Armário de registros |
| `candle_lit.fbx` | Fonte de luz próxima aos registros |
| `wall.fbx`, `wall_doorway.fbx` | Construção do arquivo se necessária |

## Cenário complementar
- `KayKit Forest Nature Pack 1.0/Assets/fbx(unity)/Color1/Tree_1_A_Color1.fbx` — árvores externas, se combinarem com o estilo escolhido.
- `KayKit Medieval Hexagon Pack 1.0.1/Assets/fbx(unity)/buildings/blue/building_church_blue.fbx` — alternativa de **capela estilizada exterior** (o modelo foi criado para tabuleiro hexagonal; verificar escala e adequação visual antes de adotar).

## Regras de uso
1. Para a versão inicial, importar somente `grave_A`, `grave_B`, `gravestone`, `floor_dirt_grave`, `fence`, `wooden_gate`, `lantern_standing`, `journal_open` e `table_small`.
2. Manter arquivos FBX e texturas relevantes dentro de `assets/models` / `assets/textures` conforme a configuração do Doriax.
3. Verificar materiais, pivôs, rotação, escala e iluminação em Play Mode e export Web.
4. Descartar objetos historicamente anacrônicos que destoem da proposta, mesmo se estiverem no mesmo pacote (por exemplo, `tractor.fbx`).
5. Pistas textuais serão geradas como interface UI (não contar com texto legível modelado nas malhas).

Referência Doriax: https://docs.doriax.org/editor/resources/
