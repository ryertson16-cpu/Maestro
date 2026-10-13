# Novidades: versão 4.2.0 (10/10/2026)

- Anexa o JSON de **notas** do Maestro. Depois do arquivo, escolhe **Salvar parcialmente** ou **Lançar notas**.
- O livro-razão guarda Parcial (ainda dá para mudar) ou Lançado (o SIAGE trava). Não preenche REC GLOBAL nem a média do período.

# Novidades: versão 4.1.9 (10/10/2026)

- Aceita **várias planilhas** no mesmo envio (turmas diferentes). Junta tudo e troca de turma no SIAGE sozinha.

# Novidades: versão 4.1.8 (10/10/2026)

- Se o SIAGE disser que a aula **já existe**, o livro-razão marca **Já no SIAGE**, não Falhou.

# Novidades: versão 4.1.7 (10/10/2026)

- Depois de cada aula no SIAGE, avisa o Maestro: **ok** ou **já estava registrada** vira Conferido no livro-razão; erro real vira Falhou.
- Não marca o lote se a senha estiver errada. Não avisa no modo teste nem enquanto a aula ainda está tentando de novo.
- Lê as colunas **Id Maestro**, **Token Maestro** e **Maestro** da planilha nova. Os botões Conferir/Falhou no site continuam.

# Novidades: versão 4.1.6 (02/10/2026)

- Lê CSV/TSV do Maestro sem embaralhar colunas: respeita aspas, vírgula, ponto e vírgula e tabulação.
- Nomes de faltas/justificados no Maestro passam a ser separados por `|`, não por `;`.
- Ao escolher o arquivo, ignora o texto colado antigo no popup.

# Novidades: versão 4.1.5 (02/10/2026)

- Lê as colunas **Faltas** e **Justificados** da planilha do Maestro (nomes separados por `;`).
- Depois de preencher data, período e tempos, marca os alunos no SIAGE: falta = interruptor desligado, justificado = azul. Presente e atraso do Maestro ficam como presente.
- Continua registrando a aula e salvando com senha como na 4.1.4.

**Para atualizar:** copie a pasta `extensions/siage-presenca` para `C:\Users\ryert\Desktop\siage-presenca` e clique em ↻ em `chrome://extensions`.

# Novidades: versão 4.1.4 (30/09/2026)

- **Corrigido o loop infinito com aula repetida:** o aviso "Já existe um registro com esta mesma data" agora é fechado e a extensão segue para a próxima aula.
- **Qualquer outro erro** ("falha na operação", "An error occurred while sending the request", tela carregando sem resposta): a extensão fecha o aviso, recarrega e repete a mesma aula, sem pedir a senha.
- **Espera maior:** aguarda até 3 minutos a resposta do SIAGE antes de considerar que travou.
- Se, ao repetir, o SIAGE disser que a aula já existe, ela conta como registrada (foi gravada na tentativa anterior).
- A extensão só para sozinha se o SIAGE disser que a senha está errada, para não bloquear sua conta. Para interromper, clique em **Parar** no painel.
