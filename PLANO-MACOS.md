# Safefy Pay para macOS

Plano inicial revisto em 22/09/2026 após leitura dos repositórios privados autorizados. A análise verifica código das branches padrão, não comprova qual revisão está em produção. Nenhuma alteração de produto foi aplicada nesta etapa.

## Resultado desejado

Aplicativo em Swift/SwiftUI com WKWebView carregando https://app.safefypay.com.br/, login na própria janela, sessão persistente, integração com menus e Dock, downloads e notificações nativas. Distribuição em DMG contendo Safefy Pay.app.

## Evidências verificadas

- `Safefy-Pay/safefy-web`: painel Next.js 16 / React 19. `src/contexts/notification-context.tsx` recebe `NotificationReceived` via SignalR, acompanha estabelecimento e ambiente e atualiza contagem e saldo. `src/providers/auth-hub-provider.tsx` trata revogação de dispositivo e alteração de status de usuário.
- `src/contexts/push-notification-context.tsx` registra tokens FCM como plataforma web. `src/components/foreground-notification-listener.tsx` mostra avisos do Firebase dentro do painel.
- `Safefy-Pay/safefy-api`: endpoints de registro e remoção de tokens existem. `Endpoints/Users/PushTokens/RegisterPushToken/RegisterPushTokenModels.cs` aceita somente web, ios e android; o endpoint associa o token ao usuário autenticado.
- `Safefy-Pay/safefy-api-core`: `Models/Database/Primary/PushToken.cs` contém as mesmas três plataformas. `Services/PushNotificationService.cs` envia mensagens FCM com data e configuração webpush; não há payload APNs nesse método. A consulta atual seleciona apenas o token, sem a plataforma.
- `Safefy-Pay/safefy_app`: aplicativo Flutter existente. O pubspec lido não declara Firebase Messaging. Sua existência não comprova suporte a push ou macOS.

## Arquitetura proposta

1. SwiftUI e AppKit para janela, menus, preferências e ciclo de vida; WKWebView com armazenamento persistente para o painel.
2. Pequena integração explícita no frontend com o host nativo, habilitada somente quando a ponte estiver disponível. Mensagens restritas ao domínio HTTPS autorizado, frame principal e esquema validado. Não expor cookies de sessão ou tokens de autenticação ao JavaScript adicional.
3. Reaproveitar os eventos SignalR existentes para notificações locais enquanto o aplicativo estiver executando. Identificar eventos por ID para evitar duplicação e respeitar conta, estabelecimento e ambiente.
4. Push remoto nativo via APNs como proposta para o app encerrado. Ampliar contratos compartilhados com plataforma macOS, roteamento por plataforma e configuração de ambiente APNs. Manter o envio FCM existente para os clientes atuais. Confirmar credenciais e provisionamento Apple antes da implementação desta etapa.
5. Registro do token nativo através da sessão autenticada do painel, com tratamento de rotação, logout, troca de conta, revogação e desativação. O servidor deve validar vínculo entre dispositivo e usuário. Token de dispositivo não é token de login.
6. Clique na notificação abre somente destino permitido; se a sessão expirou, autenticar antes de exibir os detalhes. Usar título discreto por padrão para reduzir exposição de dados financeiros na tela bloqueada.

## Sequência de execução

### 1. Prova do navegador e autenticação

- Criar projeto local Swift e protótipo WKWebView.
- Verificar versão mínima de macOS e ferramentas instaladas.
- Validar login por senha, verificação de dispositivo, persistência e logout com participação do usuário.
- Testar login Google; caso o provedor bloqueie navegador embutido, usar autenticação no navegador do sistema com retorno seguro, sem contornar a restrição.
- Validar pop-ups, links externos, anexos, comprovantes e exportações.

Entrega: protótipo navegável e registro dos fluxos comprovados.

### 2. Notificações com app executando

- Implementar ponte tipada no painel e recepção nativa com validação de origem.
- Solicitar permissão pelo macOS; preferências de som e privacidade.
- Deduplicar eventos e coordenar sons do painel e do macOS.
- Fechar janela mantém app em execução conforme preferência explícita; encerrar pelo menu termina a conexão SignalR.

Entrega: aviso nativo e abertura da tela correta para evento de teste.

### 3. Push com app encerrado

- Revisar instruções específicas dos repositórios e consumidores do pacote core antes de alterar contratos.
- Adicionar suporte macOS no core e na API; atualizar versão e referências do pacote intencionalmente.
- Configurar APNs, identificador do app, assinatura e entitlement correspondente; credenciais ficam no servidor/armazenamento seguro.
- Enviar alerta visível via APNs, sem depender de execução de JavaScript nem de push silencioso no app encerrado.
- Testar tokens inválidos, falhas transitórias, repetição de evento, logout, revogação e isolamento entre contas.
- Verificar em dispositivo real o comportamento com janela fechada, app encerrado, Mac em repouso e reconexão. Entrega depende de rede e políticas do sistema; não prometer entrega instantânea ou funcionamento com o Mac desligado.

Entrega: teste ponta a ponta em ambiente controlado; só considerar concluída após prova real.

### 4. Acabamento e distribuição

- Ícone, menus, atalhos, estados de erro/reconexão, configuração de inicialização opcional e recuperação de janela.
- Compilar para a arquitetura do Mac de teste; validar Apple Silicon e Intel caso ambos sejam alvo.
- Definir atualização do shell nativo; as atualizações do site continuam chegando pelo endereço web.
- Assinar com Developer ID, notarizar e produzir DMG; verificar instalação em ambiente limpo e atualização preservando configurações.

## Validação

Testes focados na fronteira web/nativo, validação de origem e destino, deduplicação, autorização do registro de dispositivo e roteamento APNs/FCM. Executar lint/build do frontend, build/test das APIs modificadas e testes do app. Usar eventos sintéticos em ambiente de teste, sem criar movimentações financeiras reais.

## Dependências ainda a confirmar

- Equipe Apple Developer e certificados/provisionamento disponíveis.
- Ambiente de testes e revisão efetivamente implantada do painel e das APIs.
- Identificador definitivo do aplicativo e Macs/versões suportados.
- Política desejada para notificações por estabelecimento e ambiente.

## Formatos de entrega

- `.app`: aplicativo executável.
- `.dmg`: imagem de disco para entregar o aplicativo e permitir arrastá-lo para Aplicativos; formato recomendado.
- `.pkg`: instalador com etapas e instalação de componentes; sem necessidade identificada neste projeto.

## Referências do código

- https://github.com/Safefy-Pay/safefy-web
- https://github.com/Safefy-Pay/safefy-api
- https://github.com/Safefy-Pay/safefy-api-core
- https://github.com/Safefy-Pay/safefy_app
