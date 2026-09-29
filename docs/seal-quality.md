# Selos: dificuldade e precisão (v2)

- Duplas: 4 nós em 6 s; receitas com dano base >= 18 usam 5 nós.
- Triplas: 6 nós em 8 s; receitas com dano base >= 24 usam 7 nós.
- A geometria depende da receita, não da ordem da seleção. Talentos não
  mudam o desenho ou o prazo. Dificuldade aparece antes de iniciar.
- O cronômetro começa ao tocar o primeiro nó; o multiplayer desconta o RTT
  da resposta de início como antes. Rapidez não dá bônus de dano.

## Precisão

Para cada nó, guardamos o ponto mais próximo do centro enquanto o dedo passa
por ele. Usar apenas a primeira entrada na borda puniria o arrasto contínuo.
O último nó conclui ao alcançar o círculo central ou ao soltar o dedo dentro
do prazo. Traço incompleto, inválido, interrompido ou expirado falha como antes.

A distância média aos centros, dividida pelo raio de aceitação (0,13 do
diagrama), determina a faixa:

| Erro médio normalizado | Faixa | Dano direto |
| --- | --- | --- |
| <= 0,25 | Perfeito | 100% |
| <= 0,50 | Quase perfeito | 80% |
| <= 0,75 | Estável | 60% |
| > 0,75, com todos os nós válidos | Instável | 40% |

O percentual é aplicado ao total inteiro após bônus de dano/Concentração e
redução de Fragmentação, arredondando para cima. Depois vêm divisão dos golpes
e defesa do alvo. Escudo ainda pode bloquear todo o dano. Cura, status, dano
periódico, descoberta e custo de AP ficam intactos. Básicos e IA mantêm suas
regras; não há bônus acima do dano anterior. A prévia sinaliza selo perfeito.

## Autoridade e publicação

Treino valida a geometria e os tempos; o servidor faz a mesma avaliação no
Multiplayer, recebendo o traço, nunca confiando em dano/nota enviados pelo app.
Reserva, revisão, prazo, autorização e consumo único do selo são preservados.
Isso não é atestado físico do gesto: clientes modificados ainda podem fabricar
um traço válido, uma limitação anterior que este bloco não resolve.

O início HTTP exige `sealVersion: 2`; apps antigos recebem orientação para
atualizar antes de reservar AP/turno. Publicar app e servidor juntos, sem
partidas em andamento (a geometria das receitas fortes mudou). Não publicar
somente o APK contra o servidor antigo. Nenhuma publicação foi feita aqui.

Verificação focada: quatro faixas e limites, tempos inválidos, ordem da receita,
gesto borda→centro, layouts vertical/horizontal, dano/AP, cura/status,
Concentração/Fragmentação/Escudo e protocolo HTTP. Ajuste fino da tolerância
depende de playtest com dedos em celulares reais, especialmente horizontais.
