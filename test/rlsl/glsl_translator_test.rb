# frozen_string_literal: true

require_relative "../test_helper"

class GLSLTranslatorTest < Test::Unit::TestCase
  test "translates C to GLSL" do
    uniforms = { time: :float }
    helpers = "static inline float helper(float x) { return x * 2.0f; }"
    fragment = "return vec3_new(1.0f, 0.0f, 0.0f);"

    translator = RLSL::GLSL::Translator.new(uniforms, helpers, fragment)
    glsl = translator.translate

    assert glsl.include?("#version 450")
    assert glsl.include?("uniform ShaderUniforms")
    assert glsl.include?("float time;")
    assert glsl.include?("layout(local_size_x = 8, local_size_y = 8)")
  end

  test "supports custom GLSL version" do
    translator = RLSL::GLSL::Translator.new({}, "", "", version: "430")
    glsl = translator.translate
    assert glsl.include?("#version 430")
  end

  test "replaces vec2_new with vec2" do
    translator = RLSL::GLSL::Translator.new({}, "", "vec2_new(1.0f, 2.0f)")
    glsl = translator.translate
    assert glsl.include?("vec2(1.0f, 2.0f)")
  end

  test "replaces vec3_new with vec3" do
    translator = RLSL::GLSL::Translator.new({}, "", "vec3_new(1.0f, 2.0f, 3.0f)")
    glsl = translator.translate
    assert glsl.include?("vec3(1.0f, 2.0f, 3.0f)")
  end

  test "replaces math functions" do
    translator = RLSL::GLSL::Translator.new({}, "", "sqrtf(x) sinf(y) cosf(z)")
    glsl = translator.translate
    assert glsl.include?("sqrt(x)")
    assert glsl.include?("sin(y)")
    assert glsl.include?("cos(z)")
  end

  test "removes static keyword" do
    translator = RLSL::GLSL::Translator.new({}, "static float foo;", "")
    glsl = translator.translate
    assert_false glsl.include?("static float")
  end

  test "handles empty code" do
    translator = RLSL::GLSL::Translator.new({}, nil, nil)
    glsl = translator.translate
    assert glsl.include?("void main()")
  end

  test "generates proper uniform types" do
    uniforms = { time: :float, mouse: :vec2, pos: :vec3, color: :vec4 }
    translator = RLSL::GLSL::Translator.new(uniforms, "", "")
    glsl = translator.translate

    assert glsl.include?("float time;")
    assert glsl.include?("vec2 mouse;")
    assert glsl.include?("vec3 pos;")
    assert glsl.include?("vec4 color;")
  end
end

class GLSLIntegrationTest < Test::Unit::TestCase
  test "RLSL.to_glsl generates GLSL code" do
    glsl = RLSL.to_glsl(:test_glsl) do
      uniforms { float :time }
      helpers(:c) { "" }
      fragment { "return vec3_new(1.0f, 0.0f, 0.0f);" }
    end

    assert_kind_of String, glsl
    assert glsl.include?("#version 450")
    assert glsl.include?("float time;")
  end

  test "RLSL.to_glsl accepts version parameter" do
    glsl = RLSL.to_glsl(:test_glsl_version, version: "430") do
      uniforms { float :time }
      helpers(:c) { "" }
      fragment { "" }
    end

    assert glsl.include?("#version 430")
  end
end
