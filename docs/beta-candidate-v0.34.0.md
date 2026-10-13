# Candidato Android 0.34.0+34

APK de validação do polimento do BETA TEST, ainda não publicado como release.
Base anterior: v0.33.0+33. O nome de versão segue o formato numérico exigido pelo
atualizador existente; “candidato” identifica a etapa, não um sufixo de versão.

## Conteúdo

- Câmera, esquiva direcional e transições da conjuração refinadas.
- Áreas de perigo e impactos legíveis; HP com feedback de dano/cura.
- Controles responsivos ao toque e identificação do elemento da magia.
- Entrada curta, guia na pausa, saída protegida e movimento reduzido.
- Sem mudanças no backend, assinatura ou saves dos outros modos.

## Evidências e estado

- 37 verificações beta aprovadas no conjunto; análise Dart limpa.
- Mais 19 testes focados aprovados: áudio/atualizador (16) e configurações (3).
- Build de release concluído em 13/10/2026; workflow e verificação local aprovados.
- Certificado e package ID iguais à v0.33.0; versionCode aumentou de 33 para 34.
- 24/24 sons presentes e não vazios no APK; nenhuma permissão Android adicionada.
- APK não depurável; assinatura de compatibilidade existente preservada. Ainda é
  certificado Android Debug, não a assinatura definitiva de produção.
- Instalação por atualização, fluidez, áudio e estabilidade reais: pendentes.
- ADB sem dispositivo também após o build; emulador não instalado. Solicitada
  conexão USB ao usuário. Testes automatizados não comprovam reprodução sonora,
  desempenho físico nem preservação dos dados numa instalação real.

## Identificação do artefato

- Branch: `codex/beta-candidate-v0.34.0`.
- Commit compilado: `88c5f45dbebd5c323ab71da86c600c7bb3a6395c`.
- [Build GitHub Actions](https://github.com/MarlonFer77/jogo-elementos/actions/runs/38441944182).
- Artefato: `jogo-elementos-apk`, ID `11837775672` (não é uma release publicada).
- Arquivo local: `app/build/candidate-v0.34.0/app-release.apk`.
- Tamanho: 58.183.518 bytes.
- SHA-256: `cb662c01a5dd8d6982c9c300b4f937fbc1c2239b42e75ea8548dd36c40ab24ab`.
  Hash local idêntico ao registrado pelo workflow.
- Certificado SHA-256: `ec257adaebff1cc384e6d1765eb8ffc4cb12b303d6fe4525dd4d3abf2877f6bd`.
- Package: `com.example.app`; versionName `0.34.0`; versionCode `34`.
- Android mínimo: API 24; target: API 36; ABIs: arm64-v8a, armeabi-v7a, x86_64.

Esses requisitos de atualização passaram, mas não substituem `install -r` no
aparelho com a versão anterior e conferência dos dados. Não publicar nem trocar
a chave para contornar falha de instalação. Se houver correção no código após
este candidato, gerar novo artefato com versionCode maior e repetir o aceite.

## Aceite no celular

Não desinstalar o jogo nem limpar dados. Instalar o candidato por cima da versão
atual. Conferir versão 0.34.0 e preservação de perfis, descobertas e progresso.
Depois, no BETA TEST:

1. Concluir três encontros; testar derrota, reinício e nova entrada.
2. Usar joystick junto de espada/magia/esquiva; girar a tela durante o movimento.
3. Alternar aplicativos e retomar; não pode haver avanço ou comando preso na pausa.
4. Cancelar a saída preserva a sessão; confirmar descarta só a sessão beta.
5. Conferir sons/mudo e movimento reduzido; jogar uma sessão prolongada.
6. Ativar diagnóstico local e copiar o relatório se houver travadas, informando
   aparelho, versão Android, tempo de jogo e ação que provocou o problema.

O diagnóstico não mede temperatura nem comprova FPS apresentado. Aprovação para
produção depende do playtest e da correção de falhas encontradas; o recorte atual
continua solo/offline com progresso temporário.
