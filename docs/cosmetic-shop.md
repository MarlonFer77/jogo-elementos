# Ateliê dos Ecos

Implementado em 15/10/2026 e publicado na [v0.37.0](release-v0.37.0.md).
Menu inicial → **Loja de cosméticos**. Primeira coleção: paletas de roupas
do herói do BETA 3D, não modelos novos nem equipamentos de combate.

| Traje | Ecos |
| --- | ---: |
| Viajante dos Ecos | Original, gratuito |
| Brasa Errante | 75 |
| Sentinela do Bosque | 100 |
| Peregrino Lunar | 175 |
| Guardião Real | 250 |

Prévia giratória usa o mesmo renderizador/malha da batalha. Selecionar um
traje apenas experimenta; comprar exige confirmação, equipar é uma ação
separada. A roupa passa a valer ao entrar no BETA e permanece após reiniciar
a partida. Cores de magia, avisos inimigos e regras de batalha não mudam.

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

Save inválido usa backup quando possível. Sem cópia válida, a loja bloqueia
compras e preserva dados; versões futuras não são sobrescritas. Falha ao ler
cosméticos não impede jogar: o BETA usa o traje original temporariamente.

Coleção compartilhada neste aparelho, não vinculada ao login. Não sincroniza
com Firebase/Multiplayer e não integra o backup online existente. Desinstalar
ou limpar dados pode perder a coleção. Backup local é recuperação de falhas,
não proteção contra adulteração do dispositivo. Não usar esta carteira como
autoridade de compras pagas ou recompensas online; isso exigirá servidor.

## Validação

22 testes focados de carteira, concorrência, marcos, corrupção/versão futura,
compra/cancelamento/equipamento, menu e BETA aprovados. Prévias revisadas em
360×640, 640×360 e 568×320; catálogo rola, prévia e ação permanecem fixas.
Validação física no celular pendente. APK e verificações nas notas da v0.37.0.
