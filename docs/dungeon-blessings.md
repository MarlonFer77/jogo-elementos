# Bênçãos da expedição

Escolhas temporárias do modo solo após vencer as salas **3, 6 e 9**.
Cada altar oferece três opções fixas; o jogador confirma uma. As escolhidas
acumulam até três por tentativa, sem custo de XP/pontos. A sala seguinte fica
bloqueada enquanto houver escolha pendente. Os 10 encontros, recompensas,
cura de até 25 HP e limite de 4 elementos/3 habilidades não mudam.

| Altar | Ofensiva | Defensiva | Energia |
| --- | --- | --- | --- |
| 3 | Ímpeto das Brasas: Fortalecimento na primeira ação de cada sala | Guarda do Peregrino: Escudo por 2 ações na abertura | Primeira Centelha: +1 AP inicial |
| 6 | Runas Gêmeas: +3 dano-base em combos de 2 elementos | Manto de Runas: combo concluído prepara Defesa de 1 ação | Reserva Profunda: limite de AP 5 → 6 |
| 9 | Eco da Trindade: dano de combos triplos ×1,2, arredondado para cima | Voto do Crepúsculo: combo aplica Enfraquecimento de 1 ação no inimigo | Fôlego da Ruína: +2 AP inicial |

## Sinergias e limites

- Ímpeto usa o Fortalecimento existente (+25% direto). A primeira ação o consome,
  inclusive Defender. A combinação com Fôlego permite abrir com um combo de 2.
- Guarda bloqueia um golpe; não neutraliza dano contínuo. Dois golpes/Fragmentação
  continuam consumindo o Escudo no primeiro impacto.
- Manto reduz o próximo golpe em 50%, não acumula reduções. Se também houver
  Escudo, as regras atuais de consumo de defesa continuam valendo.
- Voto reduz dano direto do inimigo em 25%; Escudo impede a aplicação. Não é
  Silêncio, não impede combos e não reduz dano contínuo.
- Bônus de combo não ativam com básico, Defender, receita desconhecida ou selo
  falho. Receitas puramente de suporte não passam a causar dano por Runas/Eco.
- Modificadores temporários de dano vêm depois dos modificadores da árvore,
  antes de Fortalecimento/precisão, qualidade do selo e defesa.
- Centelha + Fôlego somam 3 AP iniciais; regeneração/custos não mudam. Reserva
  não fornece energia e torna o gatilho de Concentração dependente de 6 AP.
- Efeitos de abertura reaparecem por sala, não por turno. Reiniciar a sala usa o
  mesmo checkpoint, sem somar AP/status extras ou escolher outra bênção.
- Derrota, conclusão ou abandono eliminam todas as bênçãos. XP, elementos,
  habilidades e compras da árvore continuam persistentes como antes.
- As opções são fixas, não sorteadas. Variabilidade vem da escolha da build;
  não há reroll ao fechar o aplicativo. Valores iniciais exigem playtest real.

## Implementação e persistência

`dungeon_blessings.dart` define os nove bônus com efeitos já suportados pelo
engine: status de abertura, AP, Mutation e CombinationModifier. A build permanente
continua validada sem concessões; só depois são aplicados os grants temporários
do encontro em `TrainingMatch`, exclusivamente no jogador A da Dungeon. Prévia
e execução compartilham a mesma simulação. Treino, Multiplayer, engine e regras
do servidor não receberam uma variante das bênçãos nem alterações neste bloco.

O save usa **schema 2**, mantendo a chave `dungeon_profile_v1`. `blessings` guarda
IDs na ordem dos altares; sala concluída + quantidade de escolhas determinam o
altar pendente. Isso é gravado junto do checkpoint da vitória. A confirmação
grava o ID antes de liberar a sala; falha mantém o estado anterior para retry.
O bloqueio de gravação também rejeita duas confirmações simultâneas.

Schema 1 migra sem reset. Expedições antigas já além de um altar recebem as
escolhas alcançadas ao retomar, sem XP/recompensa de sala adicional. Ordem,
quantidade, IDs e compatibilidade com a sala/estado ativo são validados; saves
futuros são recusados sem sobrescrever. O backup local anterior continua ativo.
Não rebaixar o APK depois de salvar schema 2: versões antigas não o reconhecem.
Isso protege o fluxo normal, não contra edição manual de um save offline.

## Interface / validação

Altar com três cartas no tema pergaminho, seleção antes de confirmar, botão
fixo, mensagens de gravação/erro e sons existentes. Cartas lado a lado na
horizontal e empilhadas na vertical, com rolagem apenas como fallback. Rotação
preserva a seleção ainda não confirmada. Bênçãos ativas podem ser consultadas no
acampamento e pelo ícone na batalha, reutilizando o espaço da árvore solo.

Verificações focadas cobrem migração, reabertura, duplicação, falha de gravação,
fim de tentativa, isolamento da árvore/IA/Treino, bônus e prévia de combate,
layouts/rotação e a regressão das dez salas. Capturas locais do altar em
`app/build/gameplay-preview/altar-360.png` e `altar-568.png`.
Faltam balanceamento e ergonomia em celulares reais. Sem APK, release ou deploy.
