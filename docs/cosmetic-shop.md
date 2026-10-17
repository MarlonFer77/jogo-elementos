# Ateliê dos Ecos

Implementado em 15/10/2026 e publicado na [v0.37.0](release-v0.37.0.md).
Menu inicial → **Loja de cosméticos** → Ateliê dos Ecos.
Ampliação local ainda não publicada: categorias Trajes, Técnicas e Relíquias,
com modelos próprios, prévia animada e equipamentos exclusivos do BETA solo.

| Traje | Ecos |
| --- | ---: |
| Viajante dos Ecos | Original, gratuito |
| Brasa Errante | 75 |
| Sentinela do Bosque | 100 |
| Peregrino Lunar | 175 |
| Guardião Real | 250 |
| Anjo da Aurora — asas e auréola | 300 |
| Demônio das Cinzas — asas, chifres e cauda | 300 |
| Arthur de Camelot — coroa, armadura e tabardo | 350 |

Prévia giratória e botão Testar animação usam o mesmo domínio/renderizador da
batalha, em sessão descartável, sem gastar Ecos ou alterar o equipamento real.
Comprar exige confirmação; equipar é outra ação. A seleção passa a valer ao
entrar no BETA e permanece ao reiniciar a partida. Toque no nome/info do item
para ler a descrição completa, inclusive na horizontal. Remover restaura o
padrão sem apagar a compra nem devolver Ecos. Trocar traje preserva relíquias.

Grimório → Equipamento mostra o conjunto realmente carregado na sessão,
incluindo traje, técnicas, relíquias e bônus. Consulta disponível antes de
entrar e com o jogo pausado; não compra, troca ou consome recursos. PH são
temporários da sessão, mas compras da loja permanecem no aparelho.
Prévia interrompe animação ao sair do app (Testar animação reinicia), sem
projéteis/avisos flutuantes encobrindo o personagem. A bênção de Excalibur
usa a cor do elemento/combinação e a conserva até terminar o golpe, mesmo
depois de consumir a carga. Nenhuma mudança adicional de dano/efeitos.

HUD mantém o alerta de vida baixa e lista os efeitos simultâneos com ícone,
tempo e descrição por toque longo. Queimadura/maldição usam anéis separados.
Perseu informa qual efeito foi negado, realça o peitoral por 0,7s e usa o som
existente de purificação (respeitando volume/mudo). Não implica bloqueio de
dano: o impacto continua sendo aplicado. Feedback pausa e limpa com a sessão.

## Técnicas e relíquias

| Item | Ecos | Efeito |
| --- | ---: | --- |
| Corte Giratório | 125 | Giro visual; mantém cone frontal, contato em 0,16s e dano |
| Golpe Saltado | 125 | Salto visual; não evita dano nem ignora colisões |
| Mortal do Viajante | 150 | Salto/rotação na esquiva; mesma distância, recarga e invulnerabilidade |
| Excalibur | 300 | +4 de dano na espada; conjuração concluída invoca Merlin e abençoa próximo corte com +3 e elemento conjurado, por até 5s |
| Capa de Mercerus | 200 | +10 agilidade = +10% de deslocamento normal/canalização/ataque; esquiva inalterada |
| Peitoral de Perseu | 250 | Imunidade à queimadura/maldição dos inimigos; dano de impacto inalterado |

Espaços independentes: traje, técnica de espada, técnica de esquiva, arma,
capa e peitoral. Corte Giratório e Golpe Saltado substituem um ao outro sem
perder a técnica comprada. Trajes/técnicas nunca dão bônus mecânicos.

Merlin é uma aparição breve com chapéu, barba e cajado; não é aliado/collider.
Bênção não acumula, é consumida mesmo se o corte errar e termina ao trocar
de área, perder ou vencer. Bônus combina com Lâmina Rúnica (+8), sem multiplicadores.

Para a proteção ter função real, impactos de guardiões aplicam queimadura
(3s, 2 HP/s, total 6) e elfos negros aplicam maldição (4s, regeneração de MP
de 9/s para 4,5/s). Reaplicar renova duração, não intensidade. Só golpes que
acertam fora da invulnerabilidade aplicam efeitos. Avisos, anel e HUD mostram
o estado; pausa congela duração, transição/fim limpa tudo. Perseu bloqueia
apenas esses efeitos e informa a imunidade. Esquivar evita impacto e status.

## Economia gratuita e local

- 100 Ecos iniciais; +25 por nível da Dungeon após o primeiro.
- +100 Ecos por expedição da Dungeon concluída.
- Progresso anterior também conta. Recompensas são conciliadas ao abrir ou
  recarregar a loja, com maiores marcos já creditados registrados no save.
- Reabrir a loja ou restaurar uma Dungeon com progresso menor não repete
  créditos já recebidos. BETA/Treino/Multiplayer não concedem Ecos neste bloco.
- Sem dinheiro real, anúncios, sorteios, expiração, serviços ou dependências novos.

## Persistência e limites

`cosmetics_local_v1` usa RecoverablePreferences com carteira, inventário,
equipamento e marcos no mesmo documento. Operações read-modify-write são
serializadas entre instâncias no mesmo isolate. Comprar item já adquirido
é idempotente; item inválido, saldo insuficiente ou equipamento não adquirido
são rejeitados. UI só confirma depois de salvar.

Chave preservada, documento v2 com espaços de equipamento. v1 é lido sem
perder saldo, compras, traje ou marcos; espaços novos começam vazios e a
próxima alteração salva v2. Referências inexistentes, itens não adquiridos e
itens no espaço errado são rejeitados. Não instalar APK anterior sobre o save v2.

Save inválido usa backup quando possível. Sem cópia válida, a loja bloqueia
compras e preserva dados; versões futuras não são sobrescritas. Falha ao ler
cosméticos não impede jogar: o BETA usa o traje original temporariamente.

Coleção compartilhada neste aparelho, não vinculada ao login. Não sincroniza
com Firebase/Multiplayer e não integra o backup online existente. Desinstalar
ou limpar dados pode perder a coleção. Backup local é recuperação de falhas,
não proteção contra adulteração do dispositivo. Não usar esta carteira como
autoridade de compras pagas ou recompensas online; isso exigirá servidor.

## Validação

Ampliação: 44 testes focados aprovados, incluindo migração v1, concorrência,
marcos, corrupção/versão futura, compra/equipar/remover, reinício com equipamentos,
dano, bênção, agilidade, status, esquiva e renderização. Análise estática limpa.
Loja verificada em 320×568, 360×640, 640×360 e 568×320; catálogo rola, ação e
prévia ficam fixas. Malhas e poses revisadas em montagem local.
Validação física de visual, fluidez e persistência por atualização ainda pendente.
Nenhum APK/release/push/backend neste bloco; a versão publicada continua v0.38.0.
