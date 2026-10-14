require "test_helper"

class Oauth::ConnectTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      email: "oauth-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @password = @professor.encrypted_password
  end

  test "signs in an existing professor by verified google email without changing the password" do
    outcome = Oauth::Connect.new(google_auth(email: @professor.email, uid: "g-1")).call

    assert outcome.ok?
    assert_equal @professor.id, outcome.professor.id
    assert_equal @password, outcome.professor.reload.encrypted_password
    assert_equal "google_oauth2", outcome.professor.identities.first.provider
  end

  test "reuses a stored identity" do
    @professor.identities.create!(provider: "google_oauth2", uid: "g-77", email: @professor.email)

    outcome = Oauth::Connect.new(google_auth(email: "other@maestro.test", uid: "g-77")).call

    assert_equal @professor.id, outcome.professor.id
    assert_equal 1, @professor.identities.count
  end

  test "creates a professor when google email is new" do
    outcome = Oauth::Connect.new(google_auth(email: "novo-#{SecureRandom.hex(4)}@escola.test", uid: "g-new")).call

    assert outcome.ok?
    assert outcome.professor.persisted?
    assert_equal "Ana Lima", outcome.professor.name
  end

  test "does not create an account when instagram sends no email" do
    auth = OmniAuth::AuthHash.new(
      provider: "instagram",
      uid: "ig-9",
      info: { name: "Ana", nickname: "ana.ig", email: nil }
    )

    outcome = Oauth::Connect.new(auth).call

    assert_not outcome.ok?
    assert_equal :missing_email, outcome.error
  end

  test "links instagram to the signed-in professor" do
    auth = OmniAuth::AuthHash.new(
      provider: "instagram",
      uid: "ig-22",
      info: { name: "Ana", nickname: "ana.ig", email: nil }
    )

    outcome = Oauth::Connect.new(auth, current_professor: @professor).call

    assert outcome.ok?
    assert_equal "instagram", @professor.identities.find_by!(uid: "ig-22").provider
    assert_equal @password, @professor.reload.encrypted_password
  end

  test "rejects an identity already used by another professor" do
    other = Professor.create!(
      name: "Outra",
      email: "outra-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    other.identities.create!(provider: "facebook", uid: "fb-1")

    outcome = Oauth::Connect.new(
      OmniAuth::AuthHash.new(
        provider: "facebook",
        uid: "fb-1",
        info: { email: @professor.email, name: "Ryertson" }
      ),
      current_professor: @professor
    ).call

    assert_equal :taken, outcome.error
  end

  private

  def google_auth(email:, uid:)
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email, name: "Ana Lima" },
      extra: { raw_info: { "email_verified" => true } }
    )
  end
end
