# frozen_string_literal: true

module Documents
  class ProfessorGuide
    FONT_DIR = "/usr/share/fonts/truetype/dejavu"
    MARK = Rails.root.join("app/assets/images/maestro-m-neon.png")
    OUTPUT = Rails.root.join("docs/Maestro-guia-do-professor.pdf")

    def self.write!(path = OUTPUT)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, new.render)
      path
    end

    def render
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :portrait,
        margin: [48, 48, 56, 48],
        info: {
          Title: "Maestro — guia completo",
          Author: "Maestro",
          Subject: "Uso do caderno (SEE-PB / SIAGE) e recursos técnicos de execução"
        }
      )

      register_fonts(pdf)
      cover(pdf)
      chapters.each_with_index do |chapter, index|
        draw_chapter(pdf, chapter, last: index == chapters.size - 1)
      end
      number_pages(pdf)
      pdf.render
    end

    private

    def register_fonts(pdf)
      regular = File.join(FONT_DIR, "DejaVuSans.ttf")
      bold = File.join(FONT_DIR, "DejaVuSans-Bold.ttf")
      return unless File.file?(regular) && File.file?(bold)

      pdf.font_families.update(
        "DejaVu" => {
          normal: regular,
          bold: bold
        }
      )
      pdf.font "DejaVu"
    end

    def cover(pdf)
      pdf.move_down 36
      if File.file?(MARK)
        pdf.image MARK.to_s, fit: [92, 92], position: :center
        pdf.move_down 18
      end

      pdf.fill_color "5B4BDB"
      pdf.text "MAESTRO", size: 12, style: :bold, align: :center, character_spacing: 3
      pdf.move_down 10
      pdf.fill_color "20263D"
      pdf.text "Guia completo", size: 28, style: :bold, align: :center
      pdf.move_down 8
      pdf.fill_color "707891"
      pdf.text "Uso do caderno e recursos técnicos de execução", size: 12, align: :center
      pdf.move_down 6
      pdf.text "SEE-PB  ·  gerado em #{I18n.l(Date.current)}", size: 10, align: :center

      pdf.move_down 28
      callout(
        pdf,
        "Este arquivo junta duas partes. A primeira é o passo a passo do professor: " \
        "chamada, notas, SIAGE, Lira e aviso para o grupo. A segunda descreve com o que o Maestro " \
        "roda de verdade neste computador e no servidor: Ruby, Rails, SQLite, Hotwire, jobs, " \
        "cérebro da Lira, extensão Chrome e o que ainda está estacionado."
      )

      pdf.move_down 18
      pdf.fill_color "20263D"
      pdf.text "Como usar este guia", size: 13, style: :bold
      pdf.move_down 6
      pdf.fill_color "3A415C"
      pdf.text(
        "Parte 1 — na primeira semana, siga os capítulos na ordem. Depois, volte pelo sumário " \
        "para o recado do dia. Parte 2 — para quem sobe o caderno, instala a extensão ou troca chave da Lira.",
        size: 10,
        leading: 3
      )

      pdf.move_down 16
      draw_table_of_contents(pdf)
      pdf.start_new_page
    end

    def draw_table_of_contents(pdf)
      pdf.fill_color "5B4BDB"
      pdf.text "Sumário", size: 13, style: :bold
      pdf.move_down 10

      number = 0
      catalog.each do |section|
        pdf.fill_color "5B4BDB"
        pdf.text section[:part], size: 11, style: :bold
        pdf.move_down 6
        pdf.fill_color "20263D"
        section[:chapters].each do |chapter|
          number += 1
          pdf.text "#{number}.  #{chapter[:title]}", size: 10, leading: 3
        end
        pdf.move_down 10
      end
    end

    def catalog
      [
        { part: "Parte 1 — Como usar o caderno", chapters: usage_chapters },
        { part: "Parte 2 — Recursos técnicos", chapters: technical_chapters }
      ]
    end

    def chapters
      catalog.flat_map do |section|
        [
          {
            title: section[:part],
            blocks: [
              p("Os capítulos a seguir pertencem a #{section[:part].sub(/\AParte \d+ — /, '').downcase}.")
            ]
          }
        ] + section[:chapters]
      end
    end

    def usage_chapters
      [
        {
          title: "O que o Maestro é (e o que não é)",
          blocks: [
            p("O Maestro é o caderno digital da sua conta de professor: turmas, alunos, diário, atividades, médias, monitoramento, projetos e conversa com a Lira. O mesmo caderno aparece no site, no atalho do Windows e — se o WhatsApp da conta estiver vinculado — no celular, falando com você, não com a família."),
            p("Ele não substitui o SIAGE. O portal continua sendo o sistema oficial da SEE-PB. O caderno organiza o lançamento e a extensão SIAGE Presença Automática preenche Frequência e Registro de Avaliações a partir dos seus dados."),
            h3("Regras que não mudam"),
            bullets([
              "Atraso não é falta. No caderno o atraso fica laranja; no SIAGE entra como presença.",
              "REC GLOBAL o SIAGE calcula. Recuperação no Maestro existe por atividade, no lançamento — nunca como preenchimento de REC GLOBAL.",
              "Projetos (turma, Professor Nota 10, Escola Nota 10) não misturam com nota de unidade do SIAGE.",
              "A Lira consulta o caderno. Ela não lança nota, falta nem envio ao portal.",
              "Mensagem para o grupo dos alunos é texto para copiar e colar. O Maestro não dispara no grupo."
            ])
          ]
        },
        {
          title: "Primeira vez: conta, escola e perfil",
          blocks: [
            steps([
              "Crie a conta no site (e-mail e senha) ou entre depois com Google, Facebook ou Instagram, sem trocar a senha já cadastrada.",
              "Abra Configurações pelo avatar. Cadastre a escola, a regional (GRE) e o brasão. Esse brasão aparece no caderno e nos PDFs (relatório do aluno, da atividade, do simulado).",
              "Em Editar perfil: nome, foto, como quer ser chamado, sexo (professor / professora), telefone e o WhatsApp em que a Lira fala com você.",
              "No mesmo perfil, informe CPF e senha do SIAGE uma vez. A senha fica cifrada no caderno; o Maestro não a grava em arquivo de projeto nem a mostra depois.",
              "Confira a assinatura (período de teste e plano mensal). Sem acesso pleno, o caderno e o WhatsApp da Lira não abrem."
            ]),
            p("Na tela inicial você vê a turma em uso, o briefing do dia e os atalhos: Diário, Atividades, Monitoramento, Projetos, Turmas, Alunos, Disciplinas e Maestro.")
          ]
        },
        {
          title: "Mapa do caderno",
          blocks: [
            p("O menu de baixo (e o comando Ctrl/Cmd+K) leva às quatro áreas. A turma escolhida no seletor acompanha Diário, Atividades e Monitoramento."),
            bullets([
              "Diário — calendário letivo, meu horário, aulas, planos de aula, Abrir SIAGE e Envios SIAGE (livro-razão).",
              "Turmas — lista de turmas, alunos (ficha, frequência, matrícula) e projetos pedagógicos.",
              "Atividades — entregas e notas da turma, banco de questões, correção por QR, atividade online (Forms) e simulado ENEM.",
              "Monitoramento — alertas de nota, entrega e frequência; conselho de classe quando a turma está escolhida."
            ]),
            p("O sino no topo guarda avisos das automações deste computador (chamada do dia, briefing). Configurações e perfil ficam no avatar, não misturados com o SIAGE.")
          ]
        },
        {
          title: "Turmas, alunos e matrículas",
          blocks: [
            steps([
              "Em Turmas, crie a turma (nome, ano, turno, nível de ensino). Uma turma 2ª H é outra turma que a 2ª I — a Lira também trata assim.",
              "Cadastre o aluno ou importe a lista em Matrículas → Importar. O vínculo aluno–turma é a matrícula ativa; mantenha o SIAGE alinhado a esses nomes.",
              "Para vários alunos de uma vez, use matrícula em lote na turma.",
              "Na ficha do aluno: foto, ocorrências, frequência do mês, atividades e o PDF Relatório individual (mesmo cabeçalho padrão: professor, escola, brasão e data).",
              "Na turma, o PDF da lista (roster) serve para conferência em papel."
            ]),
            p("Se o nome no caderno não bater com o do SIAGE, a extensão deixa aquele aluno de fora e avisa. Ajuste a ficha antes de reenviar.")
          ]
        },
        {
          title: "Diário: calendário, horário, aula e chamada",
          blocks: [
            h3("Calendário e horário"),
            steps([
              "Em Calendário, marque dias letivos e feriados do ano. Dá para gerar aulas a partir do horário.",
              "Em Meu horário, envie o PDF da grade da escola. O Maestro lê os tempos da semana.",
              "Gere a semana ou crie a aula avulsa no calendário (disciplina, data, tempo SIAGE)."
            ]),
            h3("Registrar a aula"),
            steps([
              "Abra Diário (ou Aulas) com a turma certa. Confira data, tema, disciplina, período e tempo.",
              "Se a aula tiver atividade, marque no formulário: título, tipo, bimestre, peso e data-limite. A atividade nasce ligada à aula.",
              "Planos de aula (modelos) poupam o preenchimento de objetivo, conteúdo e metodologia."
            ]),
            h3("Chamada"),
            steps([
              "No Diário, faça a chamada do tempo: presente, falta, falta justificada ou atraso.",
              "Salve. Para mandar já ao portal, use Salvar e baixar este tempo ou deixe pendente no livro-razão.",
              "O PDF do diário do dia (cabeçalho padrão) imprime a chamada daquela data."
            ]),
            callout_text("Atraso conta presença no SIAGE. Não use falta para quem chegou tarde. Justificada é falta justificada, não atraso.")
          ]
        },
        {
          title: "Atividades: lançar, adaptar, relatório e aviso do grupo",
          blocks: [
            p("Em Atividades, escolha a turma. Filtre por bimestre e por Da turma / Adaptadas. Clique no card para abrir o lançamento."),
            steps([
              "No card selecionado, ajuste bimestre e peso, monte questões, gere a folha, crie versão adaptada ou abra o relatório em PDF.",
              "No lançamento, marque entrega (data de recebimento) e nota de 0 a 10. Situações: em andamento, entregue, entregue com atraso, não entregou. Entrega depois do limite é atraso de atividade — não é falta na chamada.",
              "REC, quando a atividade é prova, entra neste lançamento por aluno — não existe tela de REC GLOBAL no Maestro.",
              "Versão adaptada: escolha os alunos e se substitui a da turma (entra na média) ou complementa (não entra). Quem substitui some do lançamento da atividade original.",
              "Relatório da atividade: PDF com o mesmo cabeçalho do relatório do aluno (professor · data) e a tabela Nome / Situação / Data de recebimento."
            ]),
            h3("Aviso para o WhatsApp da turma"),
            steps([
              "No card da atividade (ou no lançamento), clique em Aviso do grupo.",
              "O texto já vem com quem não entregou. Troque o recorte para Com atraso ou Resumo da turma.",
              "Edite se quiser, copie e cole no grupo. A Lira não envia.",
              "Pedidos mais livres (reunião de pais, boa prova) ficam no Maestro: peça a mensagem citando a turma."
            ]),
            p("A média ponderada do bimestre é a soma (nota × peso) dividida pela soma dos pesos das atividades com nota lançada. Atividade sem nota não entra na conta; nota 0 entra.")
          ]
        },
        {
          title: "Banco de questões, QR, Forms e simulado ENEM",
          blocks: [
            h3("Banco e folha"),
            steps([
              "Crie questões objetivas ou discursivas no Banco de questões.",
              "Em Montar questões na atividade, acrescente itens, gere a folha em PDF e o gabarito com QR."
            ]),
            h3("Corrigir por QR"),
            steps([
              "Abra Corrigir por QR no computador (código na tela).",
              "No celular, leia o QR, escolha o aluno e lance as respostas. A nota volta para o caderno."
            ]),
            h3("Atividade online (Google Forms)"),
            steps([
              "Exporte a planilha de respostas do Forms.",
              "Em Atividade online, envie o arquivo: o Maestro cria ou atualiza aula, presença e nota, sem misturar com projeto."
            ]),
            h3("Simulado ENEM (2º dia: CN + MT)"),
            steps([
              "Crie o simulado da turma e confira o gabarito (PDF oficial). 90 itens: 45 Ciências da Natureza + 45 Matemática.",
              "Cartão oficial 91–180 é mapeado para 1–90. Envie um ou vários PDFs dos cartões. Nome manuscrito a Lira tenta ler; o que não casar fica em pendentes para você atribuir.",
              "A escala de acertos pula a faixa 5,0: 45 acertos (metade) já valem média 6,0. A Lira sugere a nota; você confirma o lançamento — ela não lança sozinha.",
              "O relatório em PDF traz CN, MT, total e turma."
            ])
          ]
        },
        {
          title: "Notas, fechamento e recuperação",
          blocks: [
            steps([
              "Em Notas e médias (a partir da turma ou de Atividades), escolha o bimestre. Veja média da turma, quem está em recuperação e quem ainda não tem nota.",
              "Ajuste pesos e feche o bimestre quando a turma estiver conferida. O fechamento guiado percorre o que falta.",
              "Exportar boletim gera o PDF da turma. Exportar 3 unidades para o SIAGE gera o JSON/planilha das unidades — sem projetos.",
              "Recuperação por atividade/prova lança-se no aluno; a média do período e a REC GLOBAL continuam com o SIAGE."
            ])
          ]
        },
        {
          title: "SIAGE: extensão, livro-razão e o que o portal calcula",
          blocks: [
            p("Extensão: SIAGE Presença Automática #{Siage::EXTENSION_VERSION}. Só atua em professor.see.pb.gov.br."),
            h3("Instalar no Chrome"),
            steps([
              "Abra chrome://extensions e ative o Modo do desenvolvedor.",
              "Carregar sem compactação: pasta da extensão (no projeto, extensions/siage-presenca).",
              "Confira o nome e a versão no cartão. Atualize pelo ↻ do cartão, não pelo Atualizar do topo."
            ]),
            h3("Fluxo do dia"),
            steps([
              "Faça a chamada no Diário e deixe as aulas no livro-razão (Envios SIAGE), ou baixe o JSON daquele tempo.",
              "Clique em Abrir SIAGE. A extensão usa CPF e senha do perfil, entra em Diário → Visualizar Minhas Turmas e na prancheta da turma.",
              "Frequência: verde presença, vermelho falta, azul justificada. Atraso do caderno vira presença.",
              "Notas: aba Registro de Avaliações, unidades e recuperações. Salvar parcialmente ainda permite mudança; Lançar notas o SIAGE trava. O livro guarda Parcial ou Lançado.",
              "Conferido = o portal aceitou agora. Já no SIAGE = o portal já tinha (não é falha). Falhou = erro de envio — use Falhou / Conferido à mão se precisar."
            ]),
            callout_text("O Maestro não preenche REC GLOBAL nem a média do período. Não enterre o SIAGE: Abrir SIAGE e o livro-razão ficam no Diário, em destaque.")
          ]
        },
        {
          title: "Projetos pedagógicos",
          blocks: [
            p("Em Projetos: turma, Professor Nota 10 e Escola Nota 10. Etapas, prazos e evidências. Atraso de etapa não gera falta e não altera nota de unidade."),
            steps([
              "Crie o projeto, vincule turmas e acrescente etapas.",
              "Anexe evidências nas etapas. O PDF do projeto usa o cabeçalho da escola.",
              "Nunca exporte projeto como unidade do SIAGE."
            ])
          ]
        },
        {
          title: "Monitoramento e conselho",
          blocks: [
            p("O Monitoramento junta, na turma e no mês: média abaixo de 4 (cuidado), entre 4 e 6 (atenção), atividade sem entrega e frequência/atraso em excesso. Atraso na chamada continua não sendo falta; o alerta de atraso é outro recorte."),
            steps([
              "Filtre por turma, mês e tipo de alerta. Abra o aluno para ver o detalhe.",
              "Conselho: gere o parecer do bimestre (a Lira/o caderno monta o texto com frequência, atrasos e notas). Edite antes de usar.",
              "Há PDF de resultado de atividade pelo monitoramento e importação de resultados quando fizer sentido na sua rotina.",
              "Digest por e-mail, se ligado, resume alertas — não altera o caderno."
            ])
          ]
        },
        {
          title: "Maestro: conversa no site, atalho do PC e WhatsApp do professor",
          blocks: [
            p("A Lira é o caderno falando com você. Abertura típica: “Tudo bem, professor(a) [nome].” Ela só usa os dados da sua conta."),
            h3("Onde falar"),
            bullets([
              "Maestro — histórico completo no site.",
              "Atalho Maestro no topo — lembrete ou recado rápido, sem abrir o histórico. Ex.: “me lembra da reunião amanhã às 19h” (sino, com o caderno aberto neste PC).",
              "WhatsApp do número cadastrado no perfil — os mesmos comandos e as mesmas consultas. Não é o grupo da turma."
            ]),
            h3("Comandos curtos"),
            bullets([
              "hoje — aulas, chamada e pendências do dia",
              "status — caderno neste PC, WhatsApp, cérebro da conversa, avisos",
              "avisos — últimos recados da automação",
              "ajuda — lista resumida"
            ]),
            h3("Perguntas soltas"),
            p("Exemplos: frequência da Maria na 2ª A; notas da 3ª O; alertas da 2ª F; mensagem para o grupo da 3ª O alertando quem não entregou a “Lista de genética”. Com o cérebro ligado neste servidor, a Lira consulta ferramentas do caderno. Sem cérebro, o interpretador local cobre o essencial."),
            p("Automações (Configurações): horários de aviso neste computador. Só funcionam com o aplicativo aberto. Não lançam nota, falta nem SIAGE.")
          ]
        },
        {
          title: "Documentos em PDF",
          blocks: [
            p("O cabeçalho padrão traz brasão da escola, título, professor e a data de geração. Use depois de cadastrar escola e brasão em Configurações."),
            bullets([
              "Relatório individual do aluno",
              "Lista da turma",
              "Diário do dia",
              "Folha da atividade e gabarito/QR",
              "Relatório da atividade (entregas)",
              "Boletim / notas da turma",
              "Resultado de prova (atividade cujo título começa com Prova)",
              "Relatório do simulado ENEM",
              "Relatório de projeto"
            ])
          ]
        },
        {
          title: "Rotina sugerida da semana",
          blocks: [
            steps([
              "Segunda: conferir calendário e gerar a semana pelo horário. Abrir o briefing (hoje) no Maestro ou no atalho.",
              "Todo tempo de aula: chamada no Diário → salvar → pendente no livro-razão. Se houver atividade, já nascer no formulário da aula.",
              "Quando o prazo da lista vencer: lançar entregas em Atividades → Relatório da atividade → Aviso do grupo → colar no WhatsApp da turma → Abrir SIAGE quando for a vez das unidades.",
              "Antes do conselho: Monitoramento + pareceres. Conferir médias. Fechar bimestre só com nota conferida.",
              "Projetos Nota 10: atualizar etapas no módulo Projetos, separado do livro de notas."
            ]),
            callout_text("Se algo falhar no portal, o caderno continua a fonte da verdade da sua turma. Corrija no Maestro e reabra o SIAGE. Não invente lançamento só no portal se a matrícula do caderno estiver diferente.")
          ]
        }
      ]
    end

    def technical_chapters
      [
        {
          title: "Onde o Maestro roda",
          blocks: [
            p("Hoje o caderno pleno é um aplicativo Rails que sobe neste computador (Windows + Ubuntu via WSL). O Puma escuta em 0.0.0.0 na porta 3000 para o navegador do Windows alcançar o Linux; o endereço útil é http://127.0.0.1:3000. O comando habitual é bin/rails s -b 0.0.0.0."),
            p("Fuso horário: Brasília. Idioma da interface: português do Brasil. PWA (manifest e service worker) permite atalho e algum uso offline da chamada."),
            bullets([
              "Linguagem: Ruby 4.0.6 (arquivo .ruby-version), gerenciado com mise neste ambiente.",
              "Framework: Rails 8.1 (load_defaults 8.1), aplicativo Maestro20.",
              "Servidor HTTP: Puma (3 threads por padrão, RAILS_MAX_THREADS).",
              "Sistema operacional de desenvolvimento: Ubuntu no WSL; o professor abre o Chrome/Edge no Windows."
            ]),
            callout_text("Deploy em VPS com Kamal/Docker, banco Postgres de SaaS e cobrança Asaas em produção plena estão no mapa, mas não são o modo atual deste PC. A Parte 2 descreve o que já executa.")
          ]
        },
        {
          title: "Interface: Hotwire, Importmap e CSS",
          blocks: [
            p("Não há SPA React. As telas são ERB no servidor. Turbo Drive/Frames/Streams atualizam o chat da Lira, a chamada e formulários sem recarregar a página inteira. Stimulus e scripts pinados no Importmap cobrem grade de frequência, calendário, paleta de comandos, tema, QR, microfone da Lira e o atalho Maestro."),
            bullets([
              "propshaft — pipeline de assets do Rails 8.",
              "importmap-rails — JavaScript ESM sem Node no dia a dia.",
              "turbo-rails e stimulus-rails — Hotwire.",
              "application.css — tema claro/escuro e o layout do caderno.",
              "jbuilder — JSON quando a extensão ou o SIAGE pedem arquivo."
            ])
          ]
        },
        {
          title: "Dados, arquivos e senha do SIAGE",
          blocks: [
            p("O banco é SQLite 3. Em desenvolvimento: storage/development.sqlite3. Em produção o desenho Rails 8 prevê quatro arquivos: primary, cache, queue e cable (Solid Cache, Solid Queue, Solid Cable), todos SQLite, pensados para um volume persistente."),
            bullets([
              "Active Record — turmas, matrículas, aulas, chamadas, atividades, notas, livro-razão, conversas da Lira.",
              "Active Storage em disco local (storage/) — foto, brasão, PDFs de cartão ENEM, evidências de projeto.",
              "image_processing — variantes de imagem quando preciso.",
              "csv e rubyzip — importação de matrícula e pacotes.",
              "Active Record Encryption — campo siage_password cifrado. A senha não vai para o Git."
            ]),
            p("Chaves de API (Lira, WhatsApp Cloud, OAuth, Asaas) entram por variáveis de ambiente (.env, dotenv-rails em desenvolvimento). LIRA_BRAIN escolhe openai ou gemini; sem chave, a Lira fica só nos comandos locais.")
          ]
        },
        {
          title: "Filas, testes e qualidade",
          blocks: [
            p("Active Job empilha trabalho que não pode travar o clique: identificar cartão ENEM (visão da Lira), processar WhatsApp, mandar boas-vindas, rodar automações do sino. Em desenvolvimento o adaptador padrão é :async (thread no próprio Puma). Em produção: Solid Queue, podendo rodar dentro do Puma (SOLID_QUEUE_IN_PUMA) num único servidor."),
            bullets([
              "IdentifyCardJob — lê PDF do cartão em segundo plano.",
              "ProcessWhatsappJob / DeliverWelcomeWhatsappJob / DeliverAutomationWhatsappJob — canal professor ↔ Lira.",
              "RunAutomationsJob — avisos no horário, só com o caderno aberto neste PC.",
              "Testes: Minitest, Capybara, Selenium. Segurança: Brakeman e bundler-audit. Estilo: rubocop-rails-omakase."
            ])
          ]
        },
        {
          title: "Entrar na conta e cobrança",
          blocks: [
            p("Devise autentica o professor (sessão, cadastro, senha). OmniAuth liga Google, Facebook e Instagram quando as chaves existem; omitir a chave esconde o botão. CSRF do OmniAuth está ligado."),
            p("Assinatura: Billing::Config (dias de teste e preço mensal). Asaas (PIX) está preparado no .env (ASAAS_API_KEY, webhook). No PC de desenvolvimento MAESTRO_BILLING_ENFORCED=false deixa o caderno aberto sem barreira de pagamento."),
            bullets([
              "Login: e-mail/senha ou conta social.",
              "Perfil: nome, foto, WhatsApp da Lira, CPF e senha SIAGE.",
              "Webhook /webhooks/asaas — só faz sentido com cobrança ligada."
            ])
          ]
        },
        {
          title: "Lira: cérebro, ferramentas e WhatsApp Cloud",
          blocks: [
            p("A conversa passa pelo Responder: primeiro comandos curtos (hoje, status, avisos, ajuda); se houver cérebro, o modelo chama ferramentas do Toolkit (turmas, aluno, frequência, notas, alertas, projetos, situação de entrega); se o modelo falhar ou não houver chave, o interpretador local responde. O texto da persona (abertura “Tudo bem, professor…”, atraso, REC, grupo) vive em Lira::Scope, para o local e a IA não divergirem."),
            bullets([
              "OpenAI — padrão gpt-4o-mini, Chat Completions, tools em formato function.",
              "Gemini — padrão gemini-2.5-flash, generateContent, function declarations.",
              "Apenas um cérebro por servidor (LIRA_BRAIN). A mesma chave lê nome manuscrito e bolhas do cartão ENEM.",
              "WhatsApp Cloud API (Meta) — token, phone number id, verify token, app secret. Webhooks em /whatsapp/webhook e /webhooks/whatsapp.",
              "Túneis HTTPS (Cloudflare trycloudflare, ngrok) entram em config.hosts no desenvolvimento, para a Meta alcançar este PC.",
              "Histórico: AgentConversation / AgentMessage no SQLite. Resposta truncada para o limite do WhatsApp (~3900 caracteres)."
            ]),
            callout_text("A Cloud API fala com o professor. Não há disparo automático para o grupo da turma nem para famílias. O aviso do grupo é texto gerado no caderno para copiar.")
          ]
        },
        {
          title: "Leitura de PDF e simulado ENEM",
          blocks: [
            p("pdf-reader extrai texto de gabarito e de cartão quando o PDF traz camada de texto. Cartão oficial manuscrito quase nunca tem o nome no texto: aí entra a visão da Lira. OpenAI recebe JPEG (pdftoppm ou ImageMagick/magick); Gemini aceita PDF inline. IdentifyCardJob identifica depois do upload em lote (card_pdfs[]), para o pedido HTTP não estourar tempo."),
            bullets([
              "90 itens (45 CN + 45 MT). Cartão 91–180 mapeado para 1–90.",
              "Escala de acertos pulando a faixa 5,0; 45 acertos → média 6,0.",
              "A Lira sugere; o lançamento da nota é do professor."
            ])
          ]
        },
        {
          title: "Extensão Chrome do SIAGE",
          blocks: [
            p("Pacote Manifest V3: SIAGE Presença Automática #{Siage::EXTENSION_VERSION}. ZIP em /baixar/extensao-siage. Permissões: activeTab, scripting, storage. Hosts: https://professor.see.pb.gov.br, cadernomaestro.com.br, www, *.onrender.com e o caderno local em http://127.0.0.1:3000."),
            bullets([
              "Service worker (background.js) orquestra o fluxo.",
              "Content scripts no portal: page-bridge (mundo MAIN), runner e grades — Frequência e Registro de Avaliações.",
              "maestro-bridge.js no caderno — recebe Abrir SIAGE, JSON da chamada e das notas.",
              "Popup para envio manual de arquivo, se o professor quiser.",
              "Resultado volta a POST /siage/extensao/resultado e atualiza o livro-razão (Conferido, Já no SIAGE, Falhou)."
            ]),
            p("O caderno gera JSON/CSV das aulas e das 3 unidades. A extensão preenche o portal; o Rails não controla o DOM do SIAGE.")
          ]
        },
        {
          title: "Como o servidor desenha os PDFs",
          blocks: [
            p("Prawn + prawn-table geram os documentos oficiais do caderno. rqrcode desenha o QR da correção. Letterhead padrão: brasão (Active Storage), título, escola/GRE, professor e data. Variante official (SEE-PB) omite a data de geração. Fontes DejaVu (TTF) neste guia, para o português não quebrar no Helvetica do AFM."),
            p("Este próprio arquivo é Documents::ProfessorGuide. Regenerar: bin/rails runner Documents::ProfessorGuide.write! — saída em docs/Maestro-guia-do-professor.pdf.")
          ]
        },
        {
          title: "Subir o caderno neste PC",
          blocks: [
            steps([
              "No Ubuntu (WSL): mise instala o Ruby do .ruby-version. bundle install.",
              "Copie .env.example para .env e preencha só o que for usar (cérebro, WhatsApp, OAuth).",
              "bin/rails db:prepare cria o SQLite em storage/.",
              "bin/rails s -b 0.0.0.0 — abra http://127.0.0.1:3000.",
              "Chrome: carregue a extensão sem compactação e confira a versão #{Siage::EXTENSION_VERSION}.",
              "Testes: bin/rails test."
            ]),
            p("Kamal (gem kamal) e Thruster existem no Gemfile para o dia em que houver VPS. config/deploy.yml ainda aponta placeholder de servidor e registry local — não use como receita de produção até esse passo ser pedido.")
          ]
        }
      ]
    end

    def draw_chapter(pdf, chapter, last: false)
      pdf.fill_color "5B4BDB"
      pdf.text chapter[:title], size: 16, style: :bold
      pdf.move_down 4
      pdf.stroke_color "5B4BDB"
      pdf.stroke_horizontal_rule
      pdf.move_down 14

      chapter[:blocks].each do |block|
        case block[:type]
        when :p then paragraph(pdf, block[:text])
        when :h3 then heading3(pdf, block[:text])
        when :bullets then list(pdf, block[:items], ordered: false)
        when :steps then list(pdf, block[:items], ordered: true)
        when :callout then callout(pdf, block[:text])
        end
      end

      pdf.start_new_page unless last
    end

    def paragraph(pdf, text)
      pdf.fill_color "3A415C"
      pdf.text text, size: 10, leading: 3, align: :justify
      pdf.move_down 10
    end

    def heading3(pdf, text)
      pdf.move_down 4
      pdf.fill_color "20263D"
      pdf.text text, size: 12, style: :bold
      pdf.move_down 6
    end

    def list(pdf, items, ordered:)
      items.each_with_index do |item, index|
        mark = ordered ? "#{index + 1}." : "•"
        pdf.fill_color "20263D"
        pdf.float { pdf.text mark, size: 10, style: :bold }
        pdf.indent(18) do
          pdf.fill_color "3A415C"
          pdf.text item, size: 10, leading: 3
        end
        pdf.move_down 6
      end
      pdf.move_down 6
    end

    def callout(pdf, body)
      box_top = pdf.cursor
      text_height = pdf.height_of(body, size: 10, leading: 3, width: pdf.bounds.width - 24)
      height = text_height + 16
      pdf.fill_color "F4F1FF"
      pdf.fill_rounded_rectangle [0, box_top], pdf.bounds.width, height, 6
      pdf.fill_color "5B4BDB"
      pdf.fill_rectangle [0, box_top], 4, height
      pdf.bounding_box([12, box_top - 8], width: pdf.bounds.width - 24, height: text_height) do
        pdf.fill_color "20263D"
        pdf.text body, size: 10, leading: 3
      end
      pdf.move_cursor_to box_top - height - 12
    end

    def number_pages(pdf)
      pdf.number_pages(
        "Maestro  ·  guia completo  ·  %<page>s / %<total>s",
        at: [0, -18],
        align: :center,
        size: 8,
        color: "707891"
      )
    end

    def p(text)
      { type: :p, text: text }
    end

    def h3(text)
      { type: :h3, text: text }
    end

    def bullets(items)
      { type: :bullets, items: items }
    end

    def steps(items)
      { type: :steps, items: items }
    end

    def callout_text(text)
      { type: :callout, text: text }
    end
  end
end
