# Validação da primeira versão

## Compilação e lógica

- Compilação de produção concluída com Xcode 27.1 e Swift 6.4.
- Aplicativo empacotado em `build/Beira.app`, com assinatura Apple Development
  reutilizada pelo arquivo local `.signing-identity`.
- Nove testes de sequências de contatos passaram, sem falhas.
- Ícone de colchetes `[ ]` aplicado à janela, ao pacote e à barra de menus.
- Retorno tátil usa `NSHapticFeedbackManager`, padrão `alignment`, limitado a
  um pulso por lote de ajuste e no máximo 20 pulsos por segundo.

## Verificações neste Mac

- Hardware identificado como MacBookPro18,1.
- A enumeração encontrou um dispositivo interno, família 105.
- `MTDeviceIsOpaqueSurface` retorna falso para este trackpad; removido o filtro
  incorreto que descartava o dispositivo.
- O diagnóstico do adaptador iniciou e encerrou o dispositivo sem erro. Durante
  seus três segundos não houve frames de contato, portanto esse diagnóstico
  não comprova a interpretação de um dedo real.
- A janela foi aberta e inspecionada. Mostrou `Trackpad do MacBook` e `AO VIVO`.
- A entrada de permissão da primeira assinatura foi removida pelos Ajustes do
  Sistema, com autenticação Touch ID feita pelo usuário.
- O pacote atual foi adicionado novamente. O Beira reconheceu a autorização e
  a janela mudou para `Pronto para deslizar`.

## Ajustes após o primeiro teste físico

O usuário confirmou que a primeira versão ajustou brilho e volume. A calibração
seguinte foi solicitada para permitir uma passada completa pela altura do trackpad.

- Quatorze testes do reconhecedor passaram, incluindo extremos em ambos os
  lados, modo fino/normal, movimentos rápidos/lentos e rejeição horizontal.
- O movimento usado para reconhecer a intenção vertical agora conta na escala.
- O limite de quatro incrementos por frame foi removido; ele descartava parte
  de movimentos rápidos. Um lote permanece limitado à escala completa.
- Uma chegada aos 6% finais de cada extremidade envia um lote suficiente para
  atingir o limite pelo sistema. Permanecer na zona não repete esse lote.
- O início horizontal rejeita aquele toque até levantar o dedo, mesmo se ele
  depois mudar de direção dentro da borda.
- O aplicativo passa a ser instalado em `/Applications/Beira.app`. O script
  `scripts/install.sh` preserva essa localização nas atualizações.

## Teste físico pendente da nova calibração

Confirmar extremos de volume e brilho em uma passada, sensação háptica, prevenção de gestos
acidentais e suspensão/retomada com dedos reais no trackpad. Eventos postados,
permissão concedida e testes simulados não são confirmação desse resultado.

Nesta versão do macOS, o painel de privacidade aparece como **Controle do
Dispositivo e Acesso a Dados**. Em versões anteriores ele é chamado de
**Acessibilidade**; ambas as referências se relacionam ao acesso usado pelo Beira.

## Versão 0.1.1

O nome exibido no cabeçalho e no rodapé dos ajustes passa a ser **Beira**, com B maiúsculo. A atualização é visual; não altera o reconhecimento de gestos nem as permissões solicitadas. As compilações públicas continuam separadas para Apple Silicon e Intel, com assinatura ad hoc.
