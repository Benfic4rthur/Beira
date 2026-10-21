# Publicação local

O Beira não usa GitHub Actions. A compilação, os testes e a geração dos downloads acontecem no Mac do mantenedor.

## Gerar os arquivos

Confira `CFBundleShortVersionString` em `Resources/Info.plist` e execute:

```sh
swift test
./scripts/release.sh
```

O script gera duas compilações nativas, `arm64` e `x86_64`, em diretórios separados. Ambas usam assinatura ad hoc, sem certificado de distribuição nem notarização. A cópia instalada em `/Applications/Beira.app` não é alterada.

Os arquivos ficam em `build/releases/v<VERSÃO>/`:

- `Beira-AppleSilicon.zip`
- `Beira-Intel.zip`
- `SHA256SUMS.txt`

Cada ZIP contém um `Beira.app`, incluindo ícone, metadados e avisos de terceiros. Confira a arquitetura com `lipo -info` e a integridade da assinatura técnica com `codesign --verify --strict`. Essas verificações não são testes físicos nem notarização.

## Publicar

Crie a tag da versão a partir do commit revisado e publique os três arquivos na seção Releases, com notas e instruções de abertura. Use a interface do GitHub para publicar. Não crie workflows de Actions.

Os nomes dos ZIPs permanecem iguais entre versões. Assim, os links `/releases/latest/download/Beira-AppleSilicon.zip` e `/releases/latest/download/Beira-Intel.zip` podem ser usados pelo site para baixar sempre a versão mais recente. Verifique os downloads públicos e compare os hashes SHA-256 antes de remover os artefatos locais.

## Limpeza

Depois de confirmar a publicação, remova apenas `.build/` e `build/` do projeto, incluindo ZIPs, executáveis e caches de compilação. Preserve o código, a documentação, a pasta `.git` e o aplicativo instalado em `/Applications/Beira.app`.
