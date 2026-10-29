ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Rails' Active Storage does `require "active_storage/service/database_service"`.
# That looks in $LOAD_PATH, not Zeitwerk. Put lib first so the Postgres adapter loads.
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
