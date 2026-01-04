# frozen_string_literal: true

require_relative "../test_helper"

class RLSLVersionTest < Test::Unit::TestCase
  test "VERSION is defined" do
    assert_not_nil RLSL::VERSION
  end

  test "VERSION is a string" do
    assert_kind_of String, RLSL::VERSION
  end

  test "VERSION follows semantic versioning format" do
    # Basic semver format: X.Y.Z
    assert_match(/\A\d+\.\d+\.\d+/, RLSL::VERSION)
  end

  test "VERSION is frozen" do
    assert RLSL::VERSION.frozen?
  end
end
