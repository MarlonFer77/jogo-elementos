# Elementos v0.30.0 — Conta recuperável e abandono

APK build 30 gerado no [Actions](https://github.com/MarlonFer77/jogo-elementos/actions/runs/37323904719),
commit `7c509f3`. Backend do mesmo commit publicado no Render em 05/10/2026:
`accounts:true`, `persistence:firestore` e `/account` sem credencial retorna 401.
Certificado do APK verificado e idêntico ao da v0.29.0; instalação real pendente.
APK requer Android 7 ou superior. Ainda não publicado como release do GitHub.

- Login e cadastro por e-mail/senha, confirmação de e-mail e recuperação de senha.
- Vínculo do perfil multiplayer antigo à conta, com comprovação de posse.
- Sessão protegida no aparelho e recuperação do perfil online ao trocar de celular.
- Desistência com confirmação, expiração de salas e prazo de turno no multiplayer.
- Build interrompido se a assinatura anterior não estiver disponível.

## Antes de instalar

Atualize por cima do app existente: não desinstale nem apague os dados antes de
vincular seu perfil multiplayer. A conta não sincroniza Treino/Dungeon nesta versão.
Quem usou vários nomes online na mesma instalação deve revisar a migração antes
de vincular: a credencial antiga da instalação deixa de autenticar após o vínculo.

## Validação pendente

Testar cadastro, confirmação, recuperação e vínculo em aparelho real; entrar com
a mesma conta em outro celular e conferir o progresso. Validar atualização sem
desinstalação e uma partida completa entre dois aparelhos. Testes automatizados
não substituem essa verificação. Backend e APK devem usar o mesmo commit.

Assinatura definitiva, backup da progressão e demais melhorias operacionais ainda
são blocos posteriores. Nenhum serviço pago integra esta atualização.
