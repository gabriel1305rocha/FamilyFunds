# Assinatura do APK Android

O Android só atualiza um app instalado se a versão nova for assinada com **a mesma chave**. Sem uma chave fixa, o workflow **Release Android** usa uma chave de debug que muda a cada execução, e aí é preciso desinstalar o app antes de instalar a versão nova.

Configure a chave uma única vez:

## 1. Gere a chave (no seu computador)

Requer o Java instalado (vem com o Android Studio).

```bash
keytool -genkey -v -keystore family-funds.jks -keyalg RSA -keysize 2048 -validity 10000 -alias familyfunds
```

Escolha uma senha forte e **guarde o arquivo `family-funds.jks` e a senha em local seguro** (gerenciador de senhas). Se perder a chave, não será possível atualizar o app sem desinstalar.

## 2. Cadastre os secrets no GitHub

Em **Settings → Secrets and variables → Actions → New repository secret**, crie:

| Secret | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | conteúdo do arquivo em base64: `base64 -w0 family-funds.jks` (Linux) ou `base64 -i family-funds.jks` (macOS) |
| `ANDROID_KEYSTORE_PASSWORD` | a senha da keystore |
| `ANDROID_KEY_ALIAS` | `familyfunds` |
| `ANDROID_KEY_PASSWORD` | a senha da chave (se for a mesma da keystore, pode repetir) |

## 3. Reinstale uma última vez

A primeira versão assinada com a chave nova tem assinatura diferente das versões de debug: desinstale o app antigo e instale essa. A partir daí, as atualizações instalam por cima.

> Nunca faça commit do arquivo `.jks` nem de `key.properties` — ambos já estão no `.gitignore`.
