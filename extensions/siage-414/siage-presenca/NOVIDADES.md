# Novidades: versão 4.1.4 (30/09/2026)

- **Corrigido o loop infinito com aula repetida:** o aviso "Já existe um registro com esta mesma data" agora é fechado e a extensão segue para a próxima aula.
- **Qualquer outro erro** ("falha na operação", "An error occurred while sending the request", tela carregando sem resposta): a extensão fecha o aviso, recarrega e repete a mesma aula, sem pedir a senha.
- **Espera maior:** aguarda até 3 minutos a resposta do SIAGE antes de considerar que travou.
- Se, ao repetir, o SIAGE disser que a aula já existe, ela conta como registrada (foi gravada na tentativa anterior).
- A extensão só para sozinha se o SIAGE disser que a senha está errada, para não bloquear sua conta. Para interromper, clique em **Parar** no painel.

**Para atualizar:** substitua a pasta pela do zip novo e clique em ↻ em `chrome://extensions`.
