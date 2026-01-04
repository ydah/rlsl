# frozen_string_literal: true

require_relative "../test_helper"

class BaseTranslatorTest < Test::Unit::TestCase
  # Create a concrete subclass for testing
  class TestTranslator < RLSL::BaseTranslator
    FUNC_REPLACEMENTS = [
      [/test_func\(/, "replaced_func("]
    ].freeze

    TYPE_MAP = {
      "int" => "integer"
    }.freeze

    def generate_shader(helpers, fragment)
      "HELPERS: #{helpers}\nFRAGMENT: #{fragment}"
    end

    def target_vec2_type
      "test_vec2"
    end

    def target_vec3_type
      "test_vec3"
    end

    def target_vec4_type
      "test_vec4"
    end
  end

  def setup
    @translator = TestTranslator.new({ time: :float }, "helper code", "fragment code")
  end

  test "initializes with uniforms, helpers, and fragment code" do
    translator = TestTranslator.new({ time: :float }, "helpers", "fragment")
    assert_not_nil translator
  end

  test "translate applies type map" do
    translator = TestTranslator.new({}, "int x = 1;", "int y = 2;")
    result = translator.translate
    assert result.include?("integer x = 1;")
    assert result.include?("integer y = 2;")
  end

  test "translate applies func replacements" do
    translator = TestTranslator.new({}, "test_func(x)", "test_func(y)")
    result = translator.translate
    assert result.include?("replaced_func(x)")
    assert result.include?("replaced_func(y)")
  end

  test "translate handles nil helpers code" do
    translator = TestTranslator.new({}, nil, "fragment")
    result = translator.translate
    assert result.include?("HELPERS:")
    assert result.include?("FRAGMENT: fragment")
  end

  test "translate handles nil fragment code" do
    translator = TestTranslator.new({}, "helpers", nil)
    result = translator.translate
    assert result.include?("HELPERS: helpers")
    assert result.include?("FRAGMENT:")
  end

  test "translate handles empty strings" do
    translator = TestTranslator.new({}, "", "")
    result = translator.translate
    assert_kind_of String, result
  end

  test "uniform_type_to_target returns float for float" do
    assert_equal "float", @translator.send(:uniform_type_to_target, :float)
  end

  test "uniform_type_to_target returns vec2 for vec2" do
    assert_equal "test_vec2", @translator.send(:uniform_type_to_target, :vec2)
  end

  test "uniform_type_to_target returns vec3 for vec3" do
    assert_equal "test_vec3", @translator.send(:uniform_type_to_target, :vec3)
  end

  test "uniform_type_to_target returns vec4 for vec4" do
    assert_equal "test_vec4", @translator.send(:uniform_type_to_target, :vec4)
  end

  test "target_float_type returns float" do
    assert_equal "float", @translator.send(:target_float_type)
  end
end

class BaseTranslatorCommonReplacementsTest < Test::Unit::TestCase
  test "common_func_replacements generates vector constructor replacements" do
    replacements = RLSL::BaseTranslator.common_func_replacements(
      target_vec2: "float2",
      target_vec3: "float3",
      target_vec4: "float4"
    )

    # Should have replacements for vec constructors
    has_vec2 = replacements.any? { |pattern, _| pattern.source.include?("vec2_new") }
    has_vec3 = replacements.any? { |pattern, _| pattern.source.include?("vec3_new") }
    has_vec4 = replacements.any? { |pattern, _| pattern.source.include?("vec4_new") }

    assert has_vec2
    assert has_vec3
    assert has_vec4
  end

  test "common_func_replacements includes math function replacements" do
    replacements = RLSL::BaseTranslator.common_func_replacements(
      target_vec2: "vec2",
      target_vec3: "vec3",
      target_vec4: "vec4"
    )

    has_sqrt = replacements.any? { |pattern, _| pattern.source.include?("sqrtf") }
    has_sin = replacements.any? { |pattern, _| pattern.source.include?("sinf") }
    has_cos = replacements.any? { |pattern, _| pattern.source.include?("cosf") }

    assert has_sqrt
    assert has_sin
    assert has_cos
  end

  test "common_func_replacements includes vector operation replacements" do
    replacements = RLSL::BaseTranslator.common_func_replacements(
      target_vec2: "vec2",
      target_vec3: "vec3",
      target_vec4: "vec4"
    )

    has_add = replacements.any? { |pattern, _| pattern.source.include?("vec2_add") }
    has_sub = replacements.any? { |pattern, _| pattern.source.include?("vec3_sub") }
    has_dot = replacements.any? { |pattern, _| pattern.source.include?("vec2_dot") }
    has_normalize = replacements.any? { |pattern, _| pattern.source.include?("vec3_normalize") }

    assert has_add
    assert has_sub
    assert has_dot
    assert has_normalize
  end
end

class BaseTranslatorNotImplementedTest < Test::Unit::TestCase
  # Test that base class raises NotImplementedError for abstract methods
  class IncompleteTranslator < RLSL::BaseTranslator
    # Don't override generate_shader or target methods
  end

  test "generate_shader raises NotImplementedError" do
    translator = IncompleteTranslator.new({}, "", "")
    assert_raise(NotImplementedError) do
      translator.translate
    end
  end

  test "target_vec2_type raises NotImplementedError" do
    translator = IncompleteTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec2_type)
    end
  end

  test "target_vec3_type raises NotImplementedError" do
    translator = IncompleteTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec3_type)
    end
  end

  test "target_vec4_type raises NotImplementedError" do
    translator = IncompleteTranslator.allocate
    assert_raise(NotImplementedError) do
      translator.send(:target_vec4_type)
    end
  end
end
