# Safefy Pay — App macOS

App nativo em Swift/AppKit/SwiftUI que empacota o painel [app.safefypay.com.br](https://app.safefypay.com.br/) num `WKWebView`, com notificações nativas, login com Google e menu de barra de status.

Contexto de produto e decisões (notas internas, não versionadas neste repositório público) está em `PLANO-MACOS.md` local.

## Build

```bash
swift build
swift test
```

## Gerar o `.app`

```bash
./scripts/build.sh
```

Gera `dist/Safefy Pay.app`, assinado apenas com assinatura **ad-hoc** (`codesign --sign -`) — sem conta paga do Apple Developer Program ainda não dá pra assinar com Developer ID nem notarizar.

## Gerar o `.dmg` para compartilhar

```bash
./scripts/make_dmg.sh
```

Gera `dist/Safefy Pay.dmg` com o ícone da Safefy no arquivo e no volume montado.

## Instalando um build ad-hoc (sem notarização)

Como o app ainda não é assinado com Developer ID nem notarizado pela Apple, o Gatekeeper do macOS vai tratar o `.dmg`/`.app` como "não identificado" em qualquer Mac que não seja o que compilou o app. Isso é esperado até resolvermos a assinatura real — **não é um build quebrado**.

Ao abrir o `.dmg` baixado, se aparecer bloqueado ou com ícone genérico na caixa "Instalar este app?":

1. Tente clicar em **Instalar** normalmente — às vezes funciona mesmo com o aviso.
2. Se for bloqueado: **Ajustes do Sistema → Privacidade e Segurança**, role até o aviso "Safefy Pay foi bloqueado…" e clique em **Abrir Assim Mesmo**.
3. Alternativa via Terminal, depois de mover o app para `/Applications`:
   ```bash
   xattr -cr "/Applications/Safefy Pay.app"
   ```

## Auto-update (Sparkle)

O app usa [Sparkle](https://sparkle-project.org/) pra checar, baixar e instalar atualizações sozinho, com feed em `appcast.xml` (nesta raiz, servido via raw.githubusercontent.com) e arquivos hospedados como GitHub Releases deste repositório.

A chave privada de assinatura EdDSA foi gerada com `generate_keys` do Sparkle e vive **só no Keychain local** de quem gerou — nunca no git. A chave pública já está em `Resources/Info.plist` (`SUPublicEDKey`).

Cortar uma nova versão:

```bash
./scripts/release.sh 0.2.0
```

Isso builda, empacota o `.dmg`, assina e gera o `appcast.xml` (usa as ferramentas oficiais do Sparkle — baixe a distribuição completa, mesma versão do `Package.swift`, em https://github.com/sparkle-project/Sparkle/releases e extraia `bin/` para `.sparkle-tools/bin/`). O script imprime os dois passos manuais finais: commitar/enviar o `appcast.xml` e criar o GitHub Release com o `.dmg` anexado.

## Pendências conhecidas

- **Login com Google**: funciona (abre um pop-up interno, processa o OAuth e cai de volta no painel autenticado), mas o retorno automático depois de logar fora do app (ex: no navegador do sistema) ainda depende de Associated Domains + Apple Developer Program, ou de um client OAuth nativo separado no Google Cloud Console.
- **Assinatura e notarização**: pendente de conta paga do Apple Developer Program.
- **Push com app encerrado**: fase 3 do plano, depende de infraestrutura APNs e mudanças nos repositórios `safefy-api`/`safefy-api-core`.
