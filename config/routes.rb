Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :professors,
             controllers: {
               sessions: "professors/sessions",
               registrations: "professors/registrations",
               omniauth_callbacks: "professors/omniauth_callbacks"
             }

  post "/professors/oauth/indisponivel",
       to: "professors/oauth_setup#create",
       as: :oauth_unconfigured

  get "/profile", to: redirect("/settings")

  resource :profile,
           only: %i[edit update],
           controller: "profiles" do
    delete :remove_photo, on: :collection
  end

  get "/configuracoes",
      to: "settings#show",
      as: :settings

  patch "/configuracoes/automacoes",
        to: "settings#update_automations",
        as: :update_automation_settings

  resources :automation_notices, only: %i[index show] do
    collection do
      patch :mark_all_read
    end
  end

  resource :school,
           only: %i[edit update],
           controller: "schools" do
    delete :remove_crest, on: :collection
  end

  resources :courses do
    collection do
      get "areas/:knowledge_area",
          to: "courses#area",
          as: :area
      get :catalog
      post :import_catalog
    end
  end

  resources :school_courses, except: :show do
    member do
      get :edit_disciplines
      patch :update_disciplines
    end
  end

  resources :grade_levels do
    collection do
      post :save_submissions
      get :exam_result
      get :activity_report, defaults: { format: :pdf }
      get :activity_notice
    end
  end

  resource :online_activity, only: %i[new create] do
    post :preview, on: :collection
  end

  resources :enem_simulados, path: "simulado-enem" do
    member do
      patch :update_key
      post :create_sheet
      post :import_sheets
      get :report, defaults: { format: :pdf }
    end

    resources :sheets,
              controller: "enem_simulado_sheets",
              only: %i[show update destroy] do
      member do
        post :suggest
        post :launch
      end
    end

    resources :pending_cards,
              controller: "enem_pending_cards",
              only: :destroy do
      member do
        post :assign
      end
    end
  end

  resources :classrooms do
    member do
      get :report, defaults: { format: :pdf }
    end
  end

  resources :students do
    member do
      get :report, defaults: { format: :pdf }
    end
    resources :occurrences,
              controller: "student_occurrences",
              only: %i[create destroy]
  end

  get "/activity_tracker",
      to: "activity_trackers#index",
      as: :activity_tracker

  # As rotas de importação devem ficar antes de resources :enrollments
  get "/enrollments/import",
      to: "enrollments#import",
      as: :import_enrollments

  post "/enrollments/import",
       to: "enrollments#import_create",
       as: :import_create_enrollments

  resources :enrollments,
            only: %i[index new create show destroy] do
    member do
      patch :move
      patch :remove_from_classroom
    end

    collection do
      get :bulk_new

      post "bulk_create/:classroom_id",
           to: "enrollments#bulk_create",
           as: :bulk_create
    end
  end

  resources :attendance_records, only: [:index] do
    collection do
      post :save
      post :save_and_export
      post :save_cell
      get :diary_pdf
    end
  end

  resources :lessons do
    collection do
      post :generate_from_timetable
    end
    member do
      post :copy
    end
  end

  resources :questions, except: :show

  get "/correcoes",
      to: "corrections#index",
      as: :corrections

  get "/g/:token",
      to: "public_corrections#show",
      as: :gabarito

  get "/g/:token/a/:student_id",
      to: "public_corrections#show",
      as: :gabarito_aluno

  post "/g/:token",
       to: "public_corrections#grade",
       as: :gabarito_grade

  post "/g/:token/cartao",
       to: "public_corrections#scan_card",
       as: :gabarito_scan

  resources :activities, only: %i[create update destroy] do
    resources :activity_questions, only: %i[create destroy] do
      member do
        patch :move
      end
    end

    member do
      get :sheet, defaults: { format: :pdf }
      get :key_sheet, path: "folha-gabarito", defaults: { format: :pdf }
      get :adapt
      get :assemble, path: "montar"
      get :open_gabarito, path: "abrir-gabarito"
      post :build_exam, path: "montar/prova"
      get :correct, path: "corrigir"
      post :grade, path: "corrigir"
      post :scan_cards, path: "cartoes"
    end

    resources :pending_cards,
              controller: "activity_pending_cards",
              only: :destroy do
      member do
        post :assign
      end
    end
  end

  resources :projects do
    member do
      get :report, defaults: { format: :pdf }
    end

    resources :project_stages, only: %i[create update destroy] do
      member do
        delete :remove_evidence
      end
    end
  end

  resources :grades, only: [:index] do
    collection do
      post :save_bimester_settings
      post :close_bimester
    end
  end

  get "/lira",
      to: "lira/chats#show",
      as: :lira

  post "/lira/messages",
       to: "lira/chats#create",
       as: :lira_messages

  resources :reminders, only: %i[index create destroy] do
    collection do
      post :due
    end
  end

  get "/whatsapp/webhook",
      to: "lira/whatsapp_webhooks#verify"
  post "/whatsapp/webhook",
       to: "lira/whatsapp_webhooks#receive"

  get "/webhooks/whatsapp",
      to: "lira/whatsapp_webhooks#verify"
  post "/webhooks/whatsapp",
       to: "lira/whatsapp_webhooks#receive"

  get "/monitoring",
      to: "monitoring#index",
      as: :monitoring

  get "/monitoring/plano",
      to: "monitoring#plan",
      as: :monitoring_plan

  patch "/monitoring/serie",
        to: "monitoring#update_series_goal",
        as: :monitoring_series_goal

  resources :bimester_actions, only: %i[create destroy]

  post "/monitoring/email_digest",
       to: "monitoring#email_digest",
       as: :email_digest_monitoring

  get "/siage/livro",
      to: "siage_ledgers#index",
      as: :siage_ledger

  get "/siage/livro/planilha",
      to: "siage_exports#ledger",
      as: :siage_ledger_export

  patch "/siage/livro/:id/verify",
        to: "siage_ledgers#verify",
        as: :verify_siage_ledger

  patch "/siage/livro/:id/fail",
        to: "siage_ledgers#fail",
        as: :fail_siage_ledger

  patch "/siage/livro/notas/:classroom_id/:bimester/partial",
        to: "siage_ledgers#grade_partial",
        as: :partial_siage_grade_ledger

  patch "/siage/livro/notas/:classroom_id/:bimester/launch",
        to: "siage_ledgers#grade_launch",
        as: :launch_siage_grade_ledger

  patch "/siage/livro/notas/:classroom_id/:bimester/fail",
        to: "siage_ledgers#grade_fail",
        as: :fail_siage_grade_ledger

  post "/siage/extensao/resultado",
       to: "siage/extension_results#create",
       as: :siage_extension_result

  get "/horario",
      to: "timetables#show",
      as: :timetable

  post "/horario",
       to: "timetables#create"

  get "/horario/aulas",
      to: "timetables#slots",
      as: :timetable_slots

  post "/horario/gerar-semana",
       to: "timetables#generate_week",
       as: :generate_timetable_week

  post "/horario/gerar-dia",
       to: "timetables#generate_day",
       as: :generate_timetable_day

  get "/calendario",
      to: "school_calendars#show",
      as: :school_calendar

  post "/calendario/dias",
       to: "school_calendars#create_day",
       as: :school_calendar_days

  post "/calendario/feriados",
       to: "school_calendars#apply_holidays",
       as: :apply_school_calendar_holidays

  post "/calendario/gerar-aulas",
       to: "school_calendars#generate_lessons",
       as: :generate_school_calendar_lessons

  post "/calendario/aula-horario",
       to: "school_calendars#create_lesson_from_timetable",
       as: :school_calendar_timetable_lesson

  post "/calendario/horarios",
       to: "school_calendars#create_entry",
       as: :school_calendar_entries

  delete "/calendario/horarios/:id",
         to: "school_calendars#destroy_entry",
         as: :school_calendar_entry

  delete "/calendario/dias/:id",
         to: "school_calendars#destroy_day",
         as: :school_calendar_day

  get "/fechamento",
      to: "bimester_closings#show",
      as: :bimester_closing

  post "/fechamento",
       to: "bimester_closings#close"

  resources :council_notes, only: %i[index update] do
    collection do
      post :generate
    end
  end

  resources :lesson_plan_templates, except: :show

  get "/manifest.json", to: "pwa#manifest"
  get "/service-worker.js", to: "pwa#service_worker"

  get "/siage",
      to: "siage_exports#help",
      as: :siage_help

  get "/siage/abrir",
      to: "siage_exports#open",
      as: :siage_open

  get "/siage/lessons/:lesson_id",
      to: "siage_exports#lesson",
      as: :siage_lesson_export

  get "/siage/attendance",
      to: "siage_exports#attendance",
      as: :siage_attendance_export

  get "/siage/grades",
      to: "siage_exports#grades",
      as: :siage_grades_export

  get "/siage/classrooms/:classroom_id/lessons",
      to: "siage_exports#classroom_lessons",
      as: :siage_classroom_lessons_export

  get "/grades/report",
      to: "grades#report",
      as: :grades_report

  post "/grades/:classroom_id/students/:student_id/recovery",
       to: "grades#save_recovery",
       as: :save_recovery_grade

  get "/monitoring/classrooms/:classroom_id/activities/:activity_id/students/:student_id/result",
       to: "monitoring#activity_result",
       defaults: { format: :pdf },
       as: :monitoring_activity_result

  post "/monitoring/import_results",
       to: "monitoring#import_results",
       as: :import_monitoring_results

  post "/monitoring/confirm_results",
       to: "monitoring#confirm_results",
       as: :confirm_monitoring_results

  get "/",
      to: "marketing#home",
      as: :marketing_home,
      constraints: ->(request) { request.env["warden"]&.user(:professor).blank? }

  get "/baixar", to: "marketing#download", as: :download_maestro

  get "/gestao", to: "platform/desk#show", as: :platform_desk
  get "/gestao/exportar", to: "platform/desk#export", as: :platform_desk_export
  get "/gestao/professores/:id", to: "platform/desk#account", as: :platform_desk_professor
  patch "/gestao/professores/:id/nota",
        to: "platform/desk#update_note",
        as: :platform_desk_professor_note
  patch "/gestao/:professor_id",
        to: "platform/desk#update",
        as: :platform_desk_account

  get "/assinatura", to: "billing/accounts#show", as: :assinatura
  post "/assinatura", to: "billing/accounts#create"

  post "/webhooks/asaas", to: "billing/webhooks#create"

  get "/empresa",
      to: "legal#home",
      as: :company

  get "/privacidade",
      to: "legal#privacy",
      as: :privacy_policy

  get "/exclusao-de-dados",
      to: "legal#data_deletion",
      as: :data_deletion

  root "dashboard#index"
end