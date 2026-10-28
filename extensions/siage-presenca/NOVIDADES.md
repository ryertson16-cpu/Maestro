# Novidades: versão 4.8.3 (27/10/2026)

- Notas: recusa o CSV de aula (`siage-aula-…`, colunas Data/Tempos) e pede o JSON ou a planilha das 3 unidades.

# Novidades: versão 4.8.2 (27/10/2026)

- Notas: aceita o **JSON** e a **planilha** (CSV/Excel) das 3 unidades. REC GLOBAL e média do período continuam com o SIAGE.

# Novidades: versão 4.8.1 (14/10/2026)

- Troca de turma: depois da primeira aula, volta à **listagem** e espera a tabela carregar. Não procura a próxima turma na tela da anterior. Se não achar, tenta 3 vezes em vez de marcar o grupo inteiro (ex.: 10 aulas da P) como erro.

# Novidades: versão 4.8.0 (14/10/2026)

- Formulário novo por aula: se a data for de outra aula (ex.: 16/09 grudada), cancela e abre **Registrar Frequência** de novo.
- Data só vale se for **igual** à do Maestro, não qualquer dd/mm.
- Tempos 4º e 5º (e os demais) são marcados na **mesma** lista; um clique fora confirma todos. Depois vêm a chamada e o Salvar.

# Novidades: versão 4.7.8 (14/10/2026)

- Tempo como na tela: **um clique** na linha (fica azul) → espera → **clica fora** (título Informações Sobre a Aula) para fechar a lista e gravar. Não clica de novo na caixinha nem na seta.

# Novidades: versão 4.7.7 (14/10/2026)

- Tempo: **um clique só** na caixinha (vários cliques marcavam e desmarcavam). Espera o SIAGE registrar (~1,2 s) antes de tentar de novo.

# Novidades: versão 4.7.6 (14/10/2026)

- Tempo: sai do campo de **pesquisa** (lupa) e clica a **caixinha** da linha (1º Tempo, 2º Tempo…). Não digita mais no filtro. Rola a lista se o tempo estiver abaixo.

# Novidades: versão 4.7.5 (14/10/2026)

- Tempo: um clique só no campo (o segundo fechava a lista). Procura o painel pela classe PrimeNG e as linhas `1º Tempo`…`9º Tempo` em `li` / `[role=option]`.

# Novidades: versão 4.7.4 (14/10/2026)

- Causa do Tempo: o SIAGE escreve **1º Tempo** (º ordinal). O código procurava **1o tempo** e não achava as linhas, daí “não há tempo vago”. Agora trata º/° como o. Clica a caixinha na linha inteira (não só o texto). Confere a data antes de abrir o Tempo.

# Novidades: versão 4.7.3 (14/10/2026)

- Tempo: o cinza na linha é só foco, não está marcado. Clica o **quadradinho** à esquerda (14px). Só aceita se a caixinha ficar checada. Não abre o Tempo com data/período vazios. Rola até o 9º se precisar.

# Novidades: versão 4.7.2 (14/10/2026)

- Tempo: digita no **filtro** da lista (1…9), **rola** até o item (7º, 8º e 9º ficam escondidos) e marca a **caixinha** no Angular. Se o pedido não marcar, usa o vago mais próximo.

# Novidades: versão 4.7.1 (14/10/2026)

- Tempo: o Maestro já envia o número (1º, 2º…). A lista do SIAGE é a de caixinhas (1º Tempo… 6º Tempo). Na 1ª tentativa marca o tempo pedido; se não achar ou não estiver vago, na 2ª tenta o **tempo vago mais próximo** e grava a aula. Só marca “já no SIAGE” se não houver nenhum tempo livre.

# Novidades: versão 4.7.0 (14/10/2026)

- Fusão com a SIAGE 4.1.4: entra em `/frequencia` pela URL, clica **Registrar Frequência**, preenche data no calendário nativo (setas prev/next + dia), período no autocomplete e tempo no `.p-dropdown`. Mantém login/Maestro, notas, interruptores da chamada e aviso roxo se a aula já existe. Não clica no `body` (isso abria “cancelar o preenchimento”).

# Novidades: versão 4.6.7 (14/10/2026)

- Painel: **roxo** = aula já no SIAGE; **vermelho** = não conseguiu preencher. Não culpa o Tempo se a data ou o período ainda estão vazios. Se data/período estão ok e o tempo não está na lista, trata como já lançada.

# Novidades: versão 4.6.6 (14/10/2026)

- Tempo: clica a **seta** da lista (não o ícone i), espera as opções e marca o número do Maestro (1º, 3º…). Período igual. Espera o SIAGE habilitar o Tempo depois da data/período.

# Novidades: versão 4.6.5 (13/10/2026)

- Maestro envia data em ISO e em `dd/mm/aaaa`, além do rótulo do período. A extensão usa esses campos. Se o SIAGE abrir o calendário ao focar a data, escolhe o mês com as setas e o dia — sem Tab/blur que apagava o campo.

# Novidades: versão 4.6.4 (13/10/2026)

- Na aba Frequência a data é **digitada** (`dd/mm/aaaa` do Maestro). Não abre mais o calendário. Período e tempo seguem na lista suspensa.

# Novidades: versão 4.6.3 (13/10/2026)

- O quadro do mês abre no Angular (ícone azul). Se o SIAGE pergunta “cancelar o preenchimento?”, responde **Não**. Depois setas, dia, período e tempo.

# Novidades: versão 4.6.2 (13/10/2026)

- Data: clica o **ícone azul** do calendário, troca o mês só com as **setas** esquerda/direita do topo e depois o dia.
- Período e Tempo: clica a **seta** da lista suspensa e escolhe o valor que veio do Maestro.

# Novidades: versão 4.6.1 (13/10/2026)

- Na aba Frequência, o calendário abre no mês de hoje. A extensão clica o bloco **Outubro 2026**, escolhe o mês da aula (Setembro, etc.) e só então o dia. Sem isso a data ficava vazia (“Data é obrigatória”).

# Novidades: versão 4.6.0 (13/10/2026)

- A chamada vai para a aba **Frequência**: clica **Registrar Frequência**, preenche data, período e tempo do Maestro e marca os interruptores. Verde = presença, vermelho = falta, azul = falta justificada. Atraso (laranja no Maestro) entra como **presença** no SIAGE. Notas continuam em **Registro de Avaliações**.

# Novidades: versão 4.5.9 (13/10/2026)

- Depois de escolher o mês, clica **fora** do combo (blur) e espera sumir “Mês é obrigatório” antes de clicar o dia.

# Novidades: versão 4.5.8 (13/10/2026)

- Espera o modal carregar, escolhe o mês, espera o **quadro** mudar, só então clica o dia.

# Novidades: versão 4.5.7 (13/10/2026)

- O cartão da extensão deixava de receber o clique nos dias da direita (07, 08, 14, 22…). Agora o clique atravessa o cartão; só Parar/Fechar continua clicável nele.

# Novidades: versão 4.5.6 (13/10/2026)

- Fecha o aviso “data posterior à atual” (clique no Outubro futuro). Muda o mês no combo pequeno, no mundo da página Angular, com seta + rolagem da lista.

# Novidades: versão 4.5.5 (13/10/2026)

- Só clica o dia quando o **título do calendário** for o mês da aula (evita clicar 03/10 no sábado achando que é 03/09). Até 3 tentativas se o formulário não abrir.

# Novidades: versão 4.5.4 (13/10/2026)

- Não marca a data como ok se o formulário não abrir. Campo **Tempo** aceita outros nomes (tempos, horário, combobox). Combo de mês encontrado mesmo sem classe PrimeNG.

# Novidades: versão 4.5.3 (13/10/2026)

- Lista de meses: clica a **seta** e **rola todos os painéis** até Setembro aparecer (a lista só desenha Janeiro–Maio no começo). Se falhar, aí sim **digita** o nome. Depois clica o dia.

# Novidades: versão 4.5.2 (13/10/2026)

- Mês: **ou** digita o nome **ou** abre a seta e rola a lista — nunca os dois no mesmo passo. O dia só é clicado depois.

# Novidades: versão 4.5.1 (13/10/2026)

- Modal de data: usa o campo **Mês** (seta → lista com rolagem, ou **digitar** o nome). Só depois clica a **caixa** do dia. O título “Outubro” do calendário não é o combo.

# Novidades: versão 4.5.0 (13/10/2026)

- Outra estratégia no modal de data: clica no texto **Outubro/Setembro** e no **número do dia** (o calendário não é uma tabela). Aulas seguem em ordem de data.

# Novidades: versão 4.4.8 (13/10/2026)

- O campo **Mês** do modal é a caixa ao lado do rótulo (não um input invisível). Se já estiver Outubro, aulas de outubro seguem. Senão, abre a lista, escreve o mês e clica (Setembro, etc.).

# Novidades: versão 4.4.7 (13/10/2026)

- O mês do Registro de Aula é um campo digitável (lista Janeiro, Fevereiro…). A extensão escreve **Setembro** / **Outubro** nesse campo e clica na opção, em vez de procurar um dropdown PrimeNG.

# Novidades: versão 4.4.6 (13/10/2026)

- O mês do Registro de Aula (setembro, outubro…) é lido só no rótulo visível do dropdown, não na lista oculta, e a opção é clicada no painel do PrimeNG.

# Novidades: versão 4.4.5 (13/10/2026)

- Preenche o modal **Selecione um mês e uma data para o Registro de Aula** (mês no dropdown e dia no calendário) em vez de falhar com “abra a aba”.

# Novidades: versão 4.4.4 (13/10/2026)

- Na aba **Registro de Aula** a extensão não para mais: segue o cadastro sem esperar a página recarregar.
- O painel conta **feitas agora**, **já no SIAGE** e **ainda faltam**, e avisa se a data/tempo já está na lista.

# Novidades: versão 4.4.3 (13/10/2026)

- A frequência do Maestro entra na aba **Registro de Aula** (data, tempo e faltas). **Registro de Avaliações** continua sendo notas. A aba Frequência do portal fica de fora deste envio.

# Novidades: versão 4.4.2 (13/10/2026)

- A senha do SIAGE pode ficar no perfil do professor (cifrada). A extensão preenche o campo de senha sozinha.

# Novidades: versão 4.4.1 (13/10/2026)

- Depois da senha, a extensão não para mais na tela de **Ano Letivo / Matrícula**: clica em **Selecionar** mesmo quando o SIAGE troca de tela sem recarregar.

# Novidades: versão 4.4.0 (13/10/2026)

- Depois do login (CPF + senha no Chrome), a extensão clica em **Selecionar**, **Diário** e **Acessar** em Visualizar Minhas Turmas.
- Na listagem, abre a turma pela **prancheta** da coluna Ação, casando com a turma do arquivo do Maestro.
- Frequência segue na aba **Frequência**; notas na aba **Registro de Avaliações**. A senha continua só na sessão do Chrome.

# Novidades: versão 4.3.0 (13/10/2026)

- O botão **Abrir SIAGE** no caderno entrega frequência e notas à extensão, abre o portal e preenche o **CPF** do perfil. A senha é pedida no Chrome, nunca gravada no Maestro.
- Se o professor já estiver na tela de notas com um JSON entregue pelo caderno, a extensão tenta **salvar parcialmente** sozinha.

# Novidades: versão 4.2.1 (13/10/2026)

- **Lançar notas** usa a mesma senha do SIAGE do campo da extensão: preenche o diálogo do portal e confirma. Se a senha estiver vazia ou for recusada, não marca o lançamento.

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
