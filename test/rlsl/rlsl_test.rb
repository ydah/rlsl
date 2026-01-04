# frozen_string_literal: true

require_relative "../test_helper"

class RLSLCacheDirTest < Test::Unit::TestCase
  test "cache_dir returns path" do
    dir = RLSL.cache_dir
    assert_kind_of String, dir
    assert dir.include?(".cache/rlsl")
  end

  test "CACHE_DIR constant is defined" do
    assert_not_nil RLSL::CACHE_DIR
  end
end
