require "csv"

class EnrollmentsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_enrollment, only: %i[show destroy]

  def index
    @enrollments = current_professor.enrollments
                                    .includes(:student, :classroom)
                                    .order(enrolled_on: :desc)
                                    .order("students.name")

    @classrooms = current_professor.classrooms.order(:name)
  end

  def show
  end

  def new
    @enrollment = current_professor.enrollments.new(
      enrolled_on: Date.current,
      status: "active"
    )

    load_form_options
  end

  def create
    @enrollment = current_professor.enrollments.new(enrollment_params)

    if @enrollment.save
      redirect_to enrollments_path,
                  notice: "Aluno matriculado com sucesso."
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if @enrollment.destroy
      redirect_to enrollments_path,
                  notice: "Matrícula removida com sucesso."
    else
      redirect_to enrollments_path,
                  alert: @enrollment.errors.full_messages.to_sentence
    end
  end

  def bulk_new
    @classroom = current_professor.classrooms.find(params[:classroom_id])

    @students = current_professor.students
                                .where(active: true)
                                .order(:name)

    @enrolled_student_ids = @classroom.students
                                      .where(active: true)
                                      .pluck(:id)
  end

  def bulk_create
    @classroom = current_professor.classrooms.find(params[:classroom_id])

    student_ids = Array(params[:student_ids])
                   .reject(&:blank?)
                   .map(&:to_i)

    if student_ids.empty?
      @students = current_professor.students
                                   .where(active: true)
                                   .order(:name)

      @enrolled_student_ids = @classroom.students
                                        .where(active: true)
                                        .pluck(:id)

      flash.now[:alert] = "Selecione pelo menos um aluno."

      return render :bulk_new, status: :unprocessable_entity
    end

    students = current_professor.students
                                .where(id: student_ids)
                                .where(active: true)

    created_count = 0
    skipped_count = 0

    Enrollment.transaction do
      students.find_each do |student|
        enrollment = current_professor.enrollments.find_or_initialize_by(
          student: student,
          classroom: @classroom
        )

        if enrollment.new_record?
          enrollment.enrolled_on = Date.current
          enrollment.status = "active"
          enrollment.save!

          created_count += 1
        else
          skipped_count += 1
        end
      end
    end

    message = "#{created_count} matrícula(s) criada(s)."

    if skipped_count.positive?
      message += " #{skipped_count} já existia(m) e foi(ram) ignorada(s)."
    end

    redirect_to classroom_path(@classroom), notice: message
  rescue ActiveRecord::RecordInvalid => error
    @students = current_professor.students
                                .where(active: true)
                                .order(:name)

    @enrolled_student_ids = @classroom.students
                                      .where(active: true)
                                      .pluck(:id)

    flash.now[:alert] = error.record.errors.full_messages.to_sentence

    render :bulk_new, status: :unprocessable_entity
  end

  def import
  end

  def import_create
    uploaded_file = params[:file]

    if uploaded_file.blank?
      flash.now[:alert] = "Selecione um arquivo CSV."

      return render :import, status: :unprocessable_entity
    end

    imported_count = 0
    created_students_count = 0
    skipped_count = 0
    errors = []

    Enrollment.transaction do
      CSV.foreach(
        uploaded_file.path,
        headers: true,
        col_sep: ";",
        encoding: "bom|utf-8"
      ).with_index(2) do |row, line_number|
        fields = row&.fields.to_a

        # Ignora linhas completamente vazias.
        next if fields.empty?
        next if fields.all? { |value| value.to_s.strip.empty? }

        name = row["nome"].to_s.strip
        registration_number = row["matricula"].to_s.strip
        classroom_name = row["turma"].to_s.strip
        enrolled_on_value = row["data_matricula"].to_s.strip
        status = row["status"].to_s.strip.downcase.presence || "active"

        if name.blank?
          errors << "Linha #{line_number}: o nome é obrigatório."
          next
        end

        if classroom_name.blank?
          errors << "Linha #{line_number}: a turma é obrigatória."
          next
        end

        unless %w[active inactive].include?(status)
          errors << "Linha #{line_number}: status inválido: #{status}."
          next
        end

        classroom = find_import_classroom(classroom_name)

        if classroom.blank?
          errors << "Linha #{line_number}: turma não encontrada: #{classroom_name}."
          next
        end

        student = find_or_initialize_student(
          name: name,
          registration_number: registration_number
        )

        was_new_student = student.new_record?

        student.name = name
        student.professor = current_professor

        if student.respond_to?(:registration_number=) &&
           registration_number.present?
          student.registration_number = registration_number
        end

        student.active = true if student.respond_to?(:active=)
        student.save!

        created_students_count += 1 if was_new_student

        enrollment = current_professor.enrollments.find_or_initialize_by(
          student: student,
          classroom: classroom
        )

        if enrollment.new_record?
          enrollment.enrolled_on = parse_import_date(enrolled_on_value)
          enrollment.status = status
          enrollment.save!

          imported_count += 1
        else
          skipped_count += 1
        end
      end

      # Impede a gravação parcial caso alguma linha apresente erro.
      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.any?
      flash.now[:alert] = errors.join(" ")

      return render :import, status: :unprocessable_entity
    end

    redirect_to enrollments_path,
                notice: "#{imported_count} matrícula(s) importada(s). " \
                        "#{created_students_count} aluno(s) criado(s). " \
                        "#{skipped_count} matrícula(s) já existia(m)."
  rescue CSV::MalformedCSVError => error
    flash.now[:alert] = "O arquivo CSV está inválido: #{error.message}"

    render :import, status: :unprocessable_entity
  rescue Date::Error
    flash.now[:alert] =
      "Existe uma data inválida. Use o formato DD/MM/AAAA."

    render :import, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.to_sentence

    render :import, status: :unprocessable_entity
  end

  def move
    @enrollment = current_professor.enrollments
                                  .where(status: "active")
                                  .find(params[:id])

    target_classroom = current_professor.classrooms.find(
      params[:classroom_id]
    )

    if target_classroom.id == @enrollment.classroom_id
      redirect_to classroom_path(@enrollment.classroom),
                  alert: "O aluno já está nesta turma."
      return
    end

    existing_enrollment = current_professor.enrollments.find_by(
      student: @enrollment.student,
      classroom: target_classroom,
      status: "active"
    )

    if existing_enrollment.present?
      redirect_to classroom_path(@enrollment.classroom),
                  alert: "O aluno já está matriculado na turma selecionada."
      return
    end

    source_classroom = @enrollment.classroom
    student = @enrollment.student

    Enrollment.transaction do
      @enrollment.update!(status: "finished")

      current_professor.enrollments.create!(
        student: student,
        classroom: target_classroom,
        enrolled_on: Date.current,
        status: "active"
      )
    end

    redirect_to classroom_path(target_classroom),
                notice: "#{student.name} foi transferido para #{target_classroom.name}."
  rescue ActiveRecord::RecordNotFound
    redirect_to classrooms_path,
                alert: "Matrícula ou turma não encontrada."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to classroom_path(@enrollment.classroom),
                alert: error.record.errors.full_messages.to_sentence
  end

  def remove_from_classroom
    @enrollment = current_professor.enrollments
                                  .where(status: "active")
                                  .find(params[:id])

    classroom = @enrollment.classroom
    student_name = @enrollment.student.name

    @enrollment.update!(status: "finished")

    redirect_to classroom_path(classroom),
                notice: "#{student_name} foi removido da turma."
  rescue ActiveRecord::RecordNotFound
    redirect_to classrooms_path,
                alert: "Matrícula não encontrada."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to classroom_path(@enrollment.classroom),
                alert: error.record.errors.full_messages.to_sentence
  end

  private

  def set_enrollment
    @enrollment = current_professor.enrollments.find(params[:id])
  end

  def enrollment_params
    params.require(:enrollment).permit(
      :student_id,
      :classroom_id,
      :enrolled_on,
      :status
    )
  end

  def load_form_options
    @students = current_professor.students
                                .where(active: true)
                                .order(:name)

    @classrooms = current_professor.classrooms.order(:name)
  end

  def find_or_initialize_student(name:, registration_number:)
    students = current_professor.students

    if registration_number.present? &&
       Student.column_names.include?("registration_number")
      students.find_or_initialize_by(
        registration_number: registration_number
      )
    else
      students.find_or_initialize_by(name: name)
    end
  end

  def parse_import_date(value)
    return Date.current if value.blank?

    Date.strptime(value, "%d/%m/%Y")
  end

  def find_import_classroom(name)
    classrooms = current_professor.classrooms

    # Primeiro tenta encontrar pelo nome exato.
    classroom = classrooms.find_by(name: name)
    return classroom if classroom.present?

    # Depois tenta encontrar pelo nome normalizado.
    normalized_name = normalize_classroom_name(name)

    classrooms.find do |candidate|
      normalize_classroom_name(candidate.name) == normalized_name
    end
  end

  def normalize_classroom_name(name)
    name.to_s
        .encode(
          "UTF-8",
          invalid: :replace,
          undef: :replace,
          replace: ""
        )
        .unicode_normalize(:nfkd)
        .downcase
        .gsub(/\p{Mn}/, "")
        .gsub(/[ºª]/, "")
        .gsub(/\b(série|serie|ano)\b/, "")
        .gsub(/\s+/, " ")
        .strip
  end
end