# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_27_180000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.string "activity_type", null: false
    t.string "adaptation_kind"
    t.boolean "adapted", default: false, null: false
    t.integer "bimester", default: 1, null: false
    t.string "correction_token"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.string "grade_mode"
    t.text "instructions"
    t.integer "lesson_id", null: false
    t.decimal "maximum_score", precision: 6, scale: 2
    t.integer "parent_activity_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 5, scale: 2, default: "1.0", null: false
    t.index ["adapted"], name: "index_activities_on_adapted"
    t.index ["correction_token"], name: "index_activities_on_correction_token", unique: true
    t.index ["lesson_id"], name: "index_activities_on_lesson_id"
    t.index ["parent_activity_id"], name: "index_activities_on_parent_activity_id"
    t.check_constraint "bimester BETWEEN 1 AND 4", name: "activities_bimester_between_one_and_four"
    t.check_constraint "weight > 0", name: "activities_weight_greater_than_zero"
  end

  create_table "activity_exam_assignments", force: :cascade do |t|
    t.integer "activity_id", null: false
    t.json "choice_maps", default: {}, null: false
    t.datetime "created_at", null: false
    t.json "item_order", default: [], null: false
    t.integer "slot", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id", "student_id"], name: "index_exam_assignments_on_activity_and_student", unique: true
    t.index ["activity_id"], name: "index_activity_exam_assignments_on_activity_id"
    t.index ["student_id"], name: "index_activity_exam_assignments_on_student_id"
    t.check_constraint "slot >= 1", name: "activity_exam_assignments_slot_positive"
  end

  create_table "activity_pending_cards", force: :cascade do |t|
    t.integer "activity_id", null: false
    t.json "answers", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.integer "filled_count", default: 0, null: false
    t.integer "student_id"
    t.string "suggested_name"
    t.datetime "updated_at", null: false
    t.index ["activity_id"], name: "index_activity_pending_cards_on_activity_id"
    t.index ["student_id"], name: "index_activity_pending_cards_on_student_id"
  end

  create_table "activity_questions", force: :cascade do |t|
    t.integer "activity_id", null: false
    t.string "bncc_skill"
    t.json "choices", default: [], null: false
    t.string "correct_letter"
    t.datetime "created_at", null: false
    t.string "kind", default: "objective", null: false
    t.decimal "points", precision: 6, scale: 2, default: "1.0", null: false
    t.integer "position", default: 1, null: false
    t.text "prompt", null: false
    t.integer "question_id"
    t.datetime "updated_at", null: false
    t.index ["activity_id", "position"], name: "index_activity_questions_on_activity_id_and_position", unique: true
    t.index ["activity_id"], name: "index_activity_questions_on_activity_id"
    t.index ["question_id"], name: "index_activity_questions_on_question_id"
  end

  create_table "activity_recipients", force: :cascade do |t|
    t.integer "activity_id", null: false
    t.datetime "created_at", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id", "student_id"], name: "index_activity_recipients_on_activity_id_and_student_id", unique: true
    t.index ["activity_id"], name: "index_activity_recipients_on_activity_id"
    t.index ["student_id"], name: "index_activity_recipients_on_student_id"
  end

  create_table "activity_submissions", force: :cascade do |t|
    t.integer "activity_id", null: false
    t.json "answers", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "professor_id", null: false
    t.decimal "score", precision: 3, scale: 1
    t.integer "student_id", null: false
    t.date "submitted_on"
    t.datetime "updated_at", null: false
    t.index ["activity_id", "student_id"], name: "index_activity_submissions_on_activity_and_student", unique: true
    t.index ["activity_id"], name: "index_activity_submissions_on_activity_id"
    t.index ["professor_id"], name: "index_activity_submissions_on_professor_id"
    t.index ["student_id"], name: "index_activity_submissions_on_student_id"
    t.check_constraint "score IS NULL OR (score >= 0 AND score <= 10)", name: "activity_submissions_score_between_zero_and_ten"
  end

  create_table "agent_conversations", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.integer "professor_id", null: false
    t.datetime "updated_at", null: false
    t.index ["professor_id", "channel", "external_id"], name: "index_agent_conversations_on_professor_channel_external", unique: true
    t.index ["professor_id"], name: "index_agent_conversations_on_professor_id"
  end

  create_table "agent_messages", force: :cascade do |t|
    t.integer "agent_conversation_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_conversation_id"], name: "index_agent_messages_on_agent_conversation_id"
    t.index ["role"], name: "index_agent_messages_on_role"
  end

  create_table "attendance_records", force: :cascade do |t|
    t.date "attendance_date", null: false
    t.datetime "created_at", null: false
    t.integer "enrollment_id", null: false
    t.integer "lesson_id"
    t.text "notes"
    t.integer "professor_id", null: false
    t.string "status", default: "present", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id", "attendance_date", "lesson_id"], name: "index_attendance_records_on_enrollment_date_lesson", unique: true
    t.index ["enrollment_id"], name: "index_attendance_records_on_enrollment_id"
    t.index ["lesson_id"], name: "index_attendance_records_on_lesson_id"
    t.index ["professor_id"], name: "index_attendance_records_on_professor_id"
  end

  create_table "automation_notices", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "fingerprint", null: false
    t.string "kind", null: false
    t.integer "professor_id", null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.datetime "whatsapp_sent_at"
    t.index ["professor_id", "fingerprint"], name: "index_automation_notices_on_professor_id_and_fingerprint", unique: true
    t.index ["professor_id", "read_at"], name: "index_automation_notices_on_professor_id_and_read_at"
    t.index ["professor_id"], name: "index_automation_notices_on_professor_id"
  end

  create_table "automation_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "hour", default: 7, null: false
    t.string "kind", null: false
    t.date "last_run_on"
    t.integer "minute", default: 30, null: false
    t.integer "professor_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "whatsapp", default: true, null: false
    t.index ["professor_id", "kind"], name: "index_automation_rules_on_professor_id_and_kind", unique: true
    t.index ["professor_id"], name: "index_automation_rules_on_professor_id"
  end

  create_table "billing_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "external_id"
    t.json "payload"
    t.integer "professor_id"
    t.string "provider", default: "asaas", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_billing_events_on_external_id"
    t.index ["professor_id"], name: "index_billing_events_on_professor_id"
  end

  create_table "bimester_settings", force: :cascade do |t|
    t.integer "bimester", null: false
    t.integer "classroom_id", null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.decimal "minimum_score", precision: 4, scale: 2, default: "6.0", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id", "bimester"], name: "index_bimester_settings_on_classroom_id_and_bimester", unique: true
    t.index ["classroom_id"], name: "index_bimester_settings_on_classroom_id"
    t.check_constraint "bimester BETWEEN 1 AND 4", name: "bimester_settings_bimester_between_one_and_four"
    t.check_constraint "minimum_score >= 0 AND minimum_score <= 10", name: "bimester_settings_minimum_score_between_zero_and_ten"
  end

  create_table "classrooms", force: :cascade do |t|
    t.boolean "active"
    t.integer "course_id"
    t.datetime "created_at", null: false
    t.integer "grade_level_id", null: false
    t.string "name"
    t.integer "professor_id", null: false
    t.integer "school_course_id"
    t.integer "school_year"
    t.string "shift"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_classrooms_on_course_id"
    t.index ["grade_level_id"], name: "index_classrooms_on_grade_level_id"
    t.index ["professor_id"], name: "index_classrooms_on_professor_id"
    t.index ["school_course_id"], name: "index_classrooms_on_school_course_id"
  end

  create_table "council_notes", force: :cascade do |t|
    t.integer "bimester", null: false
    t.text "body", null: false
    t.integer "classroom_id", null: false
    t.datetime "created_at", null: false
    t.datetime "generated_at"
    t.integer "professor_id", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_council_notes_on_classroom_id"
    t.index ["professor_id", "classroom_id", "student_id", "bimester"], name: "index_council_notes_unique_student_bimester", unique: true
    t.index ["professor_id"], name: "index_council_notes_on_professor_id"
    t.index ["student_id"], name: "index_council_notes_on_student_id"
  end

  create_table "course_disciplines", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.boolean "required", default: true, null: false
    t.integer "school_course_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_course_disciplines_on_course_id"
    t.index ["school_course_id", "course_id"], name: "index_course_disciplines_unique_link", unique: true
    t.index ["school_course_id"], name: "index_course_disciplines_on_school_course_id"
  end

  create_table "courses", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "knowledge_area", default: "matematica", null: false
    t.string "name", null: false
    t.integer "professor_id", null: false
    t.datetime "updated_at", null: false
    t.index ["knowledge_area"], name: "index_courses_on_knowledge_area"
    t.index ["professor_id"], name: "index_courses_on_professor_id"
  end

  create_table "enem_pending_cards", force: :cascade do |t|
    t.json "answers", default: []
    t.datetime "created_at", null: false
    t.integer "enem_simulado_id", null: false
    t.string "filename", null: false
    t.string "suggested_name"
    t.datetime "updated_at", null: false
    t.index ["enem_simulado_id"], name: "index_enem_pending_cards_on_enem_simulado_id"
  end

  create_table "enem_simulado_sheets", force: :cascade do |t|
    t.json "answers", default: [], null: false
    t.integer "classroom_id"
    t.integer "cn_hits"
    t.boolean "confirmed", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "enem_simulado_id", null: false
    t.integer "hits"
    t.integer "mt_hits"
    t.decimal "score", precision: 3, scale: 1
    t.integer "student_id", null: false
    t.string "suggestion_source"
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_enem_simulado_sheets_on_classroom_id"
    t.index ["enem_simulado_id", "student_id"], name: "index_enem_simulado_sheets_on_enem_simulado_id_and_student_id", unique: true
    t.index ["enem_simulado_id"], name: "index_enem_simulado_sheets_on_enem_simulado_id"
    t.index ["student_id"], name: "index_enem_simulado_sheets_on_student_id"
  end

  create_table "enem_simulados", force: :cascade do |t|
    t.integer "activity_id"
    t.date "applied_on", null: false
    t.integer "bimester", null: false
    t.integer "classroom_id", null: false
    t.datetime "created_at", null: false
    t.boolean "key_confirmed", default: false, null: false
    t.string "key_source"
    t.json "official_key", default: [], null: false
    t.integer "professor_id", null: false
    t.integer "question_count", default: 90, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id"], name: "index_enem_simulados_on_activity_id"
    t.index ["classroom_id"], name: "index_enem_simulados_on_classroom_id"
    t.index ["professor_id"], name: "index_enem_simulados_on_professor_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.integer "classroom_id", null: false
    t.datetime "created_at", null: false
    t.date "enrolled_on", null: false
    t.integer "professor_id", null: false
    t.string "status", default: "active", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_enrollments_on_classroom_id"
    t.index ["professor_id"], name: "index_enrollments_on_professor_id"
    t.index ["student_id", "classroom_id"], name: "index_enrollments_on_student_and_classroom", unique: true
    t.index ["student_id"], name: "index_enrollments_on_student_id"
  end

  create_table "grade_levels", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "professor_id", null: false
    t.datetime "updated_at", null: false
    t.index ["professor_id"], name: "index_grade_levels_on_professor_id"
  end

  create_table "lesson_plan_templates", force: :cascade do |t|
    t.text "content"
    t.integer "course_id"
    t.datetime "created_at", null: false
    t.text "methodology"
    t.text "objective"
    t.integer "professor_id", null: false
    t.text "skills"
    t.string "theme"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_lesson_plan_templates_on_course_id"
    t.index ["professor_id"], name: "index_lesson_plan_templates_on_professor_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.integer "classroom_id", null: false
    t.text "content"
    t.integer "course_id"
    t.datetime "created_at", null: false
    t.boolean "has_activity", default: false, null: false
    t.date "lesson_date", null: false
    t.integer "lesson_plan_template_id"
    t.text "methodology"
    t.text "objective"
    t.integer "professor_id", null: false
    t.string "siage_class_mode"
    t.string "siage_class_type"
    t.string "siage_period"
    t.string "siage_time_slot"
    t.text "skills"
    t.string "theme", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id", "lesson_date"], name: "index_lessons_on_classroom_id_and_lesson_date"
    t.index ["classroom_id"], name: "index_lessons_on_classroom_id"
    t.index ["course_id"], name: "index_lessons_on_course_id"
    t.index ["lesson_plan_template_id"], name: "index_lessons_on_lesson_plan_template_id"
    t.index ["professor_id"], name: "index_lessons_on_professor_id"
  end

  create_table "professor_identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.integer "professor_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["professor_id", "provider"], name: "index_professor_identities_on_professor_id_and_provider", unique: true
    t.index ["professor_id"], name: "index_professor_identities_on_professor_id"
    t.index ["provider", "uid"], name: "index_professor_identities_on_provider_and_uid", unique: true
  end

  create_table "professors", force: :cascade do |t|
    t.text "bio"
    t.string "cpf"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone"
    t.string "preferred_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "school_name"
    t.string "sex"
    t.text "siage_password"
    t.datetime "updated_at", null: false
    t.string "whatsapp_number"
    t.datetime "whatsapp_welcome_sent_at"
    t.index ["cpf"], name: "index_professors_on_cpf", unique: true
    t.index ["email"], name: "index_professors_on_email", unique: true
    t.index ["reset_password_token"], name: "index_professors_on_reset_password_token", unique: true
    t.index ["whatsapp_number"], name: "index_professors_on_whatsapp_number", unique: true
  end

  create_table "project_classrooms", force: :cascade do |t|
    t.integer "classroom_id", null: false
    t.datetime "created_at", null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_project_classrooms_on_classroom_id"
    t.index ["project_id", "classroom_id"], name: "index_project_classrooms_on_project_id_and_classroom_id", unique: true
    t.index ["project_id"], name: "index_project_classrooms_on_project_id"
  end

  create_table "project_stages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_on"
    t.integer "lesson_id"
    t.integer "position", default: 1, null: false
    t.integer "project_id", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_project_stages_on_lesson_id"
    t.index ["project_id", "position"], name: "index_project_stages_on_project_id_and_position"
    t.index ["project_id"], name: "index_project_stages_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "audience", null: false
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.text "justification"
    t.string "kind", null: false
    t.string "kind_other"
    t.text "objective"
    t.integer "professor_id", null: false
    t.text "skills"
    t.date "starts_on"
    t.string "status", default: "draft", null: false
    t.text "team_notes"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["professor_id", "kind"], name: "index_projects_on_professor_id_and_kind"
    t.index ["professor_id", "status"], name: "index_projects_on_professor_id_and_status"
    t.index ["professor_id"], name: "index_projects_on_professor_id"
  end

  create_table "questions", force: :cascade do |t|
    t.string "bncc_skill"
    t.json "choices", default: [], null: false
    t.string "correct_letter"
    t.integer "course_id"
    t.datetime "created_at", null: false
    t.string "kind", default: "objective", null: false
    t.decimal "points", precision: 6, scale: 2, default: "1.0", null: false
    t.integer "professor_id", null: false
    t.text "prompt", null: false
    t.string "tag"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_questions_on_course_id"
    t.index ["kind"], name: "index_questions_on_kind"
    t.index ["professor_id"], name: "index_questions_on_professor_id"
    t.index ["tag"], name: "index_questions_on_tag"
  end

  create_table "recovery_grades", force: :cascade do |t|
    t.integer "bimester", null: false
    t.integer "classroom_id", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.integer "professor_id", null: false
    t.decimal "score", precision: 3, scale: 1, null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_recovery_grades_on_classroom_id"
    t.index ["professor_id"], name: "index_recovery_grades_on_professor_id"
    t.index ["student_id", "classroom_id", "bimester"], name: "idx_on_student_id_classroom_id_bimester_4efe05deab", unique: true
    t.index ["student_id"], name: "index_recovery_grades_on_student_id"
    t.check_constraint "bimester BETWEEN 1 AND 4", name: "recovery_grades_bimester_between_one_and_four"
    t.check_constraint "score >= 0 AND score <= 10", name: "recovery_grades_score_between_zero_and_ten"
  end

  create_table "reminders", force: :cascade do |t|
    t.integer "automation_notice_id"
    t.integer "classroom_id"
    t.datetime "created_at", null: false
    t.datetime "fired_at"
    t.integer "professor_id", null: false
    t.datetime "remind_at", null: false
    t.string "source_text"
    t.string "title", null: false
    t.datetime "undone_at"
    t.datetime "updated_at", null: false
    t.index ["professor_id", "fired_at"], name: "index_reminders_on_professor_id_and_fired_at"
    t.index ["professor_id", "remind_at"], name: "index_reminders_on_professor_id_and_remind_at"
  end

  create_table "school_calendar_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "day", null: false
    t.string "kind", null: false
    t.string "name"
    t.integer "professor_id", null: false
    t.datetime "updated_at", null: false
    t.index ["professor_id", "day"], name: "index_school_calendar_days_on_professor_id_and_day", unique: true
    t.index ["professor_id"], name: "index_school_calendar_days_on_professor_id"
  end

  create_table "school_courses", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "professor_id", null: false
    t.datetime "updated_at", null: false
    t.index ["professor_id", "name"], name: "index_school_courses_on_professor_id_and_name", unique: true
    t.index ["professor_id"], name: "index_school_courses_on_professor_id"
  end

  create_table "schools", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "professor_id", null: false
    t.string "regional"
    t.string "regional_other"
    t.datetime "updated_at", null: false
    t.index ["professor_id"], name: "index_schools_on_professor_id", unique: true
  end

  create_table "siage_shipments", force: :cascade do |t|
    t.integer "bimester"
    t.integer "classroom_id", null: false
    t.datetime "created_at", null: false
    t.datetime "exported_at"
    t.string "filename"
    t.string "kind", null: false
    t.integer "lesson_id"
    t.text "notes"
    t.integer "professor_id", null: false
    t.string "status", default: "exported", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_siage_shipments_on_classroom_id"
    t.index ["lesson_id"], name: "index_siage_shipments_on_lesson_id"
    t.index ["professor_id", "classroom_id", "kind"], name: "idx_on_professor_id_classroom_id_kind_aeec6dc6d7"
    t.index ["professor_id", "lesson_id"], name: "index_siage_shipments_on_professor_id_and_lesson_id"
    t.index ["professor_id"], name: "index_siage_shipments_on_professor_id"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "student_occurrences", force: :cascade do |t|
    t.text "body", null: false
    t.integer "classroom_id"
    t.datetime "created_at", null: false
    t.string "kind", default: "other", null: false
    t.date "occurred_on", null: false
    t.integer "professor_id", null: false
    t.integer "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_student_occurrences_on_classroom_id"
    t.index ["professor_id"], name: "index_student_occurrences_on_professor_id"
    t.index ["student_id", "occurred_on"], name: "index_student_occurrences_on_student_id_and_occurred_on"
    t.index ["student_id"], name: "index_student_occurrences_on_student_id"
  end

  create_table "students", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "classroom_id"
    t.integer "course_id"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "professor_id", null: false
    t.string "registration_number"
    t.string "series"
    t.datetime "updated_at", null: false
    t.index ["classroom_id"], name: "index_students_on_classroom_id"
    t.index ["course_id"], name: "index_students_on_course_id"
    t.index ["professor_id"], name: "index_students_on_professor_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "asaas_checkout_url"
    t.string "asaas_customer_id"
    t.string "asaas_subscription_id"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "last_payment_at"
    t.string "plan", default: "monthly", null: false
    t.integer "professor_id", null: false
    t.string "status", default: "trialing", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["asaas_customer_id"], name: "index_subscriptions_on_asaas_customer_id"
    t.index ["asaas_subscription_id"], name: "index_subscriptions_on_asaas_subscription_id"
    t.index ["professor_id"], name: "index_subscriptions_on_professor_id", unique: true
  end

  create_table "timetable_entries", force: :cascade do |t|
    t.integer "classroom_id", null: false
    t.integer "course_id"
    t.datetime "created_at", null: false
    t.integer "period", null: false
    t.integer "professor_id", null: false
    t.string "time_slot"
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["classroom_id"], name: "index_timetable_entries_on_classroom_id"
    t.index ["course_id"], name: "index_timetable_entries_on_course_id"
    t.index ["professor_id", "classroom_id", "weekday", "period"], name: "index_timetable_entries_unique_slot", unique: true
    t.index ["professor_id"], name: "index_timetable_entries_on_professor_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "activities", column: "parent_activity_id"
  add_foreign_key "activities", "lessons"
  add_foreign_key "activity_exam_assignments", "activities"
  add_foreign_key "activity_exam_assignments", "students"
  add_foreign_key "activity_pending_cards", "activities"
  add_foreign_key "activity_pending_cards", "students"
  add_foreign_key "activity_questions", "activities"
  add_foreign_key "activity_questions", "questions"
  add_foreign_key "activity_recipients", "activities"
  add_foreign_key "activity_recipients", "students"
  add_foreign_key "activity_submissions", "activities"
  add_foreign_key "activity_submissions", "professors"
  add_foreign_key "activity_submissions", "students"
  add_foreign_key "agent_conversations", "professors"
  add_foreign_key "agent_messages", "agent_conversations"
  add_foreign_key "attendance_records", "enrollments"
  add_foreign_key "attendance_records", "professors"
  add_foreign_key "automation_notices", "professors"
  add_foreign_key "automation_rules", "professors"
  add_foreign_key "billing_events", "professors"
  add_foreign_key "bimester_settings", "classrooms"
  add_foreign_key "classrooms", "courses"
  add_foreign_key "classrooms", "grade_levels"
  add_foreign_key "classrooms", "professors"
  add_foreign_key "classrooms", "school_courses"
  add_foreign_key "council_notes", "classrooms"
  add_foreign_key "council_notes", "professors"
  add_foreign_key "council_notes", "students"
  add_foreign_key "course_disciplines", "courses"
  add_foreign_key "course_disciplines", "school_courses"
  add_foreign_key "courses", "professors"
  add_foreign_key "enem_pending_cards", "enem_simulados"
  add_foreign_key "enem_simulado_sheets", "classrooms"
  add_foreign_key "enem_simulado_sheets", "enem_simulados"
  add_foreign_key "enem_simulado_sheets", "students"
  add_foreign_key "enem_simulados", "activities"
  add_foreign_key "enem_simulados", "classrooms"
  add_foreign_key "enem_simulados", "professors"
  add_foreign_key "enrollments", "classrooms"
  add_foreign_key "enrollments", "professors"
  add_foreign_key "enrollments", "students"
  add_foreign_key "grade_levels", "professors"
  add_foreign_key "lesson_plan_templates", "courses"
  add_foreign_key "lesson_plan_templates", "professors"
  add_foreign_key "lessons", "classrooms"
  add_foreign_key "lessons", "courses"
  add_foreign_key "lessons", "lesson_plan_templates"
  add_foreign_key "lessons", "professors"
  add_foreign_key "professor_identities", "professors"
  add_foreign_key "project_classrooms", "classrooms"
  add_foreign_key "project_classrooms", "projects"
  add_foreign_key "project_stages", "lessons"
  add_foreign_key "project_stages", "projects"
  add_foreign_key "projects", "professors"
  add_foreign_key "questions", "courses"
  add_foreign_key "questions", "professors"
  add_foreign_key "recovery_grades", "classrooms"
  add_foreign_key "recovery_grades", "professors"
  add_foreign_key "recovery_grades", "students"
  add_foreign_key "school_calendar_days", "professors"
  add_foreign_key "school_courses", "professors"
  add_foreign_key "schools", "professors"
  add_foreign_key "siage_shipments", "classrooms"
  add_foreign_key "siage_shipments", "lessons"
  add_foreign_key "siage_shipments", "professors"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "student_occurrences", "classrooms"
  add_foreign_key "student_occurrences", "professors"
  add_foreign_key "student_occurrences", "students"
  add_foreign_key "students", "classrooms"
  add_foreign_key "students", "courses"
  add_foreign_key "students", "professors"
  add_foreign_key "subscriptions", "professors"
  add_foreign_key "timetable_entries", "classrooms"
  add_foreign_key "timetable_entries", "courses"
  add_foreign_key "timetable_entries", "professors"
end
