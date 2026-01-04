# frozen_string_literal: true

require_relative "../test_helper"

class RLSLTypesTest < Test::Unit::TestCase
  test "C_TYPES constant is defined" do
    assert_not_nil RLSL::C_TYPES
    assert_kind_of String, RLSL::C_TYPES
  end

  test "C_TYPES contains vec2 definition" do
    assert RLSL::C_TYPES.include?("typedef struct { float x, y; } vec2;")
  end

  test "C_TYPES contains vec3 definition" do
    assert RLSL::C_TYPES.include?("typedef struct { float x, y, z; } vec3;")
  end

  test "C_TYPES contains vec4 definition" do
    assert RLSL::C_TYPES.include?("typedef struct { float x, y, z, w; } vec4;")
  end

  test "C_TYPES contains PI definition" do
    assert RLSL::C_TYPES.include?("#define PI 3.14159265f")
  end

  test "C_TYPES contains TAU definition" do
    assert RLSL::C_TYPES.include?("#define TAU 6.28318530f")
  end

  test "UNIFORM_TYPES contains expected types" do
    assert_equal %i[float vec2 vec3 vec4 int bool mat2 mat3 mat4 sampler2D], RLSL::UNIFORM_TYPES
  end

  test "C_TYPES contains mat2 definition" do
    assert RLSL::C_TYPES.include?("typedef struct { float m[4]; } mat2;")
  end

  test "C_TYPES contains mat3 definition" do
    assert RLSL::C_TYPES.include?("typedef struct { float m[9]; } mat3;")
  end

  test "C_TYPES contains mat4 definition" do
    assert RLSL::C_TYPES.include?("typedef struct { float m[16]; } mat4;")
  end

  test "C_TYPES contains sampler2D definition" do
    assert RLSL::C_TYPES.include?("sampler2D")
  end

  test "UNIFORM_TYPES is frozen" do
    assert RLSL::UNIFORM_TYPES.frozen?
  end
end

class TypeMappingTest < Test::Unit::TestCase
  test "C_UNIFORM_TYPES maps float" do
    assert_equal "float", RLSL::TypeMapping::C_UNIFORM_TYPES[:float]
  end

  test "C_UNIFORM_TYPES maps vec2" do
    assert_equal "vec2", RLSL::TypeMapping::C_UNIFORM_TYPES[:vec2]
  end

  test "C_UNIFORM_TYPES maps vec3" do
    assert_equal "vec3", RLSL::TypeMapping::C_UNIFORM_TYPES[:vec3]
  end

  test "C_UNIFORM_TYPES maps vec4" do
    assert_equal "vec4", RLSL::TypeMapping::C_UNIFORM_TYPES[:vec4]
  end

  test "C_UNIFORM_TYPES maps int" do
    assert_equal "int", RLSL::TypeMapping::C_UNIFORM_TYPES[:int]
  end

  test "C_UNIFORM_TYPES maps bool" do
    assert_equal "int", RLSL::TypeMapping::C_UNIFORM_TYPES[:bool]
  end

  test "C_UNIFORM_TYPES maps mat2" do
    assert_equal "mat2", RLSL::TypeMapping::C_UNIFORM_TYPES[:mat2]
  end

  test "C_UNIFORM_TYPES maps mat3" do
    assert_equal "mat3", RLSL::TypeMapping::C_UNIFORM_TYPES[:mat3]
  end

  test "C_UNIFORM_TYPES maps mat4" do
    assert_equal "mat4", RLSL::TypeMapping::C_UNIFORM_TYPES[:mat4]
  end

  test "C_UNIFORM_TYPES maps sampler2D" do
    assert_equal "sampler2D", RLSL::TypeMapping::C_UNIFORM_TYPES[:sampler2D]
  end

  test "C_UNIFORM_TYPES is frozen" do
    assert RLSL::TypeMapping::C_UNIFORM_TYPES.frozen?
  end
end
