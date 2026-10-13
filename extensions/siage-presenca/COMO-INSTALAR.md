# SIAGE Presença Automática (versão 4) — como instalar e usar

## Instalar / atualizar
1. Descompacte `siage-presenca.zip`. Use a pasta `siage-presenca` que contém o `manifest.json`.
2. No Chrome, abra `chrome://extensions` e ligue o **Modo de programador**.
3. Clique em **Carregar expandida** e escolha essa pasta.
   Se já tinha uma versão antiga: remova-a antes, ou substitua a pasta e clique em ↻ no cartão da extensão.

## Usar com a planilha de todas as turmas
1. Entre no SIAGE (professor.see.pb.gov.br). Pode estar em qualquer tela.
2. Clique na extensão e, em **Planilha de aulas**, escolha o arquivo `.xlsx` (colunas Data, Tempos, Turma, Componente).
   Também dá para colar as linhas copiadas do Excel.
3. Em **Registrar só as aulas de … até …**, escolha o intervalo. O "até" já vem com a data de hoje.
4. Período: deixe **Automático pela data**.
5. Digite a **senha do SIAGE** (fica só na memória do Chrome até terminar).
6. Na primeira vez, marque **Modo teste**: a extensão abre a primeira turma e preenche só a primeira aula, sem salvar.
7. Clique em **Registrar aulas**. Para cada turma, a extensão vai à Listagem de Turmas (passa pelas páginas 1, 2…),
   clica em Visualizar, abre a aba Frequência, confere o nome da turma e do componente no topo e registra as aulas.
8. O painel no canto da página mostra o andamento por turma e os erros. O botão **Parar** interrompe;
   depois, **Continuar** no popup retoma de onde parou. Não mexa na aba enquanto ela trabalha.

## Segurança
- A extensão só registra se a turma e o componente no topo da página forem os da planilha.
- Só salva se a data no campo for exatamente a pedida.
- Se a senha for recusada, ela para na hora.
