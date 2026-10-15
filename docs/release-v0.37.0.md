# Elementos v0.37.0 — Ateliê dos Ecos e magias com identidade

## Novidades

- **Loja de cosméticos** no menu inicial: cinco trajes para o herói do BETA 3D,
  com prévia giratória, confirmação de compra, filtro de adquiridos e equipamento.
- 100 Ecos gratuitos iniciais; +25 por nível da Dungeon após o primeiro e
  +100 por expedição concluída. Progresso anterior conta; créditos são recebidos
  ao abrir/recarregar a loja, sem repetir marcos já resgatados.
- Traje equipado salvo no aparelho e mantido ao reiniciar partidas do BETA.
  Cosméticos não alteram atributos, dano ou habilidades.
- **Magias com formas próprias** na canalização, voo e impacto: Fogo, Água,
  Vento, Terra e os seis combos do BETA.
- Tornado Ígneo forma um vórtice flamejante; Vapor vira gêiser; Erupção lança
  magma e rochas; Névoa cria nuvens baixas; Lama forma uma poça com respingos;
  Estilhaços lança fragmentos giratórios.
- Magias bloqueadas dissipam localmente. Pausa e movimento reduzido respeitados.

## Limites importantes

A loja é offline, compartilhada neste aparelho e sem dinheiro real. A coleção
inicial muda as cores dos trajes do **BETA 3D**, não o visual do Treino ou
Multiplayer. Inventário e Ecos não sincronizam com Firebase nem integram o
backup online. Desinstalar/limpar dados pode perder a coleção.

O BETA continua experimental. As regras de dano, custos e alcance das magias
foram preservadas. Sem alteração no backend ou troca de assinatura definitiva.

## Atualizar e testar

Baixe **app-release.apk** nos Assets ou use o aviso do jogo. Instale por cima
da versão anterior: **não desinstale nem limpe os dados**. Confira **0.37.0**.

- Abra a loja, experimente um traje, compre, equipe e entre no BETA 3D.
- Feche/reabra o app e confira saldo, coleção e equipamento.
- Teste os seis combos, colisões com paredes e pausa, nas duas orientações.
- Confira preservação dos perfis e jogue por 15–20 minutos para avaliar
  fluidez, áudio, aquecimento e estabilidade no celular.

22 testes focados da loja/menu/BETA e 16 de magias/combos aprovados durante
a implementação. Prévias visuais revisadas; testes locais não substituem
instalação por atualização e playtest físico.

## APK verificado

- Commit compilado: `3ae2daa48efe9cac29cc09501f00af60952bdc82`.
- [Build GitHub Actions](https://github.com/MarlonFer77/jogo-elementos/actions/runs/38799530454).
- Arquivo: `app-release.apk`, 59.183.694 bytes; versão `0.37.0+37`.
- Package ID: `com.example.app`; Android 7/API 24 ou superior.
- Arquiteturas: arm64-v8a, armeabi-v7a e x86_64.
- Certificado igual ao da v0.36.0, APK não depurável e mesmas permissões.
- Assinatura ainda Android Debug, preservada para compatibilidade; definitiva pendente.
- SHA-256: `ad4f23a467d4054d971b3c2965f735b75486b10c9ee305e223da0b383101d480`.

Hash local igual ao registrado no build. Antes de publicar, 19 testes do
atualizador e o teste das dez silhuetas integradas foram reexecutados e passaram.

Publicada como Latest em 15/10/2026. Endpoint público e digest do asset
conferidos. Verificador real detectou atualização 0.36.0+36 → 0.37.0;
na própria 0.37.0+37, não oferece atualização desnecessária.
