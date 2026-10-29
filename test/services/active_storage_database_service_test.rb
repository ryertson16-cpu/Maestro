require "test_helper"

class ActiveStorageDatabaseServiceTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @service = ActiveStorage::Service::DatabaseService.new
    @key = "maestro-test-#{SecureRandom.hex(8)}"
  end

  teardown do
    ActiveStorageDatum.where("key LIKE ?", "maestro-test-%").delete_all
  end

  test "stores bytes in postgres or sqlite" do
    @service.upload(@key, StringIO.new("brasao"))

    assert @service.exist?(@key)
    assert_equal "brasao", @service.download(@key)
  end

  test "delete removes the file" do
    @service.upload(@key, StringIO.new("foto"))
    @service.delete(@key)

    refute @service.exist?(@key)
    assert_raises(ActiveStorage::FileNotFoundError) { @service.download(@key) }
  end
end
