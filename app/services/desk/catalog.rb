module Desk
  module Catalog
    module_function

    def product
      host = Billing::Access.public_host

      {
        name: "Maestro",
        site: host,
        signup_url: "#{host}/professors/sign_up",
        billing_url: "#{host}/assinatura",
        audience: "Professor da educação básica, em especial da rede estadual da Paraíba (SEE-PB / SIAGE).",
        what_it_is: "Caderno digital do professor: turmas, alunos, calendário letivo, diário, chamada, atividades, notas, projetos e envio ao SIAGE. Atraso não é falta.",
        price_monthly: Billing::Config::MONTHLY_PRICE.to_s("F"),
        price_annual: Billing::Config::ANNUAL_PRICE.to_s("F"),
        currency: "BRL",
        trial_days: Billing::Config::TRIAL_DAYS,
        this_channel: "WhatsApp de atendimento do Maestro (vendas e suporte). Não consulta diário nem lança nota.",
        caderno_channel: "Depois de assinar, o professor vincula o próprio WhatsApp em Configurações → Editar perfil. Aí o Maestro/Lira consulta só a conta dele. Este número comercial não substitui esse vínculo.",
        never: [
          "Não envia recado para família ou grupo de alunos.",
          "Não inventa turma, aluno, nota ou falta.",
          "Não pede senha do SIAGE nem chave de API.",
          "Não trata atraso como falta.",
          "Não preenche REC GLOBAL."
        ],
        agent_instructions: agent_instructions(host)
      }
    end

    def agent_instructions(host)
      <<~TEXT.strip
        Você atende professores no WhatsApp comercial do Maestro (#{host}).
        Fale em português, curto e claro. Trate a pessoa como professor ou professora.

        Use as ferramentas do Maestro para: (1) ver se o número já é cliente; (2) gravar o recado.
        Se for cliente com assinatura ok, oriente o caderno no site e o WhatsApp do perfil para consultar turmas.
        Se não for cliente, explique o caderno, o teste de #{Billing::Config::TRIAL_DAYS} dias e o plano mensal de R$ #{Billing::Config::MONTHLY_PRICE.to_s('F').tr('.', ',')}. Link: #{host}/assinatura

        Não consulte frequência, nota ou aluno neste canal. Não invente dado escolar. Não fale com responsável de aluno.
      TEXT
    end
  end
end
