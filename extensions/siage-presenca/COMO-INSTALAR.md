# SIAGE Presença Automática (versão 4.8.4) — como instalar e usar

## Instalar / atualizar
1. Baixe o ZIP em https://cadernomaestro.com.br/baixar (botão da extensão SIAGE) e extraia. Use a pasta `siage-presenca` que contém o `manifest.json`.
2. No Chrome, abra `chrome://extensions` e ligue o **Modo do desenvolvedor**. No Edge: `edge://extensions`.
3. Clique em **Carregar sem compactação** (ou **Load unpacked**) e escolha essa pasta.
   Se já tinha uma versão antiga: extraia por cima da pasta e clique em ↻ no cartão da extensão.

## Usar com a planilha de todas as turmas
1. Entre no SIAGE (professor.see.pb.gov.br). Pode estar em qualquer tela.
2. Clique na extensão e, em **Planilha de aulas**, escolha o arquivo `.xlsx` (colunas Data, Tempos, Turma, Componente).
   Também dá para colar as linhas copiadas do Excel.
3. Em **Registrar só as aulas de … até …**, escolha o intervalo. O "até" já vem com a data de hoje.
4. Período: deixe **Automático pela data**.
5. A senha do SIAGE pode vir do perfil no Maestro. Se faltar, digite na extensão. A mesma senha confirma o **Lançar notas**.
6. Na primeira vez, marque **Modo teste**: a extensão abre a primeira turma e preenche só a primeira aula, sem salvar.
7. Clique em **Registrar aulas**. Para cada turma, a extensão vai à Listagem de Turmas (passa pelas páginas 1, 2…),
   clica na prancheta, abre a aba **Frequência**, clica em **Registrar Frequência**, preenche data, período e tempo e marca a chamada. Notas vão em **Registro de Avaliações**.
8. O painel no canto da página mostra o andamento por turma e os erros. O botão **Parar** interrompe;
   depois, **Continuar** no popup retoma de onde parou. Não mexa na aba enquanto ela trabalha.

## Notas (JSON ou planilha)
1. No Maestro, baixe **JSON das 3 unidades** ou **Planilha das 3 unidades**.
2. Abra a tela de notas da turma no SIAGE.
3. Na extensão, em **Notas do SIAGE**, escolha o arquivo (`.json`, `.csv` ou Excel).
4. Use a senha do campo acima. **Salvar parcialmente** ainda dá para mudar; **Lançar notas** o portal trava.

## Segurança
- A extensão só registra se a turma e o componente no topo da página forem os da planilha.
- Só salva se a data no campo for exatamente a pedida.
- Se a senha for recusada, ela para na hora.
