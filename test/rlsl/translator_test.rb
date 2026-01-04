# frozen_string_literal: true

require_relative "../test_helper"

class MSLShaderTest < Test::Unit::TestCase
  test "initializes with name, uniforms, and source" do
    uniforms = { time: :float, color: :vec3 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "// MSL source")

    assert_equal :test, shader.name
    assert_equal "// MSL source", shader.msl_source
  end

  test "metal? returns true" do
    shader = RLSL::MSL::Shader.new(:test, {}, "")
    assert_true shader.metal?
  end

  test "pack_uniforms packs float uniform" do
    uniforms = { time: :float }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { time: 1.5 }, 800, 600)

    # Resolution (2 floats = 8 bytes) + padding (if needed) + time float
    assert_kind_of String, data
    assert_equal 256, data.length  # Padded to 256 bytes
  end

  test "pack_uniforms packs vec2 uniform" do
    uniforms = { pos: :vec2 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { pos: [1.0, 2.0] }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms packs vec3 uniform" do
    uniforms = { color: :vec3 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { color: [1.0, 0.5, 0.0] }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms packs vec4 uniform" do
    uniforms = { rgba: :vec4 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, { rgba: [1.0, 0.5, 0.0, 1.0] }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms handles multiple uniforms" do
    uniforms = { time: :float, pos: :vec2, color: :vec3 }
    shader = RLSL::MSL::Shader.new(:test, uniforms, "")

    data = shader.send(:pack_uniforms, {
      time: 1.0,
      pos: [100.0, 200.0],
      color: [1.0, 0.0, 0.0]
    }, 800, 600)

    assert_kind_of String, data
    assert_equal 256, data.length
  end

  test "pack_uniforms includes resolution at start" do
    shader = RLSL::MSL::Shader.new(:test, {}, "")

    data = shader.send(:pack_uniforms, {}, 800, 600)

    # First 8 bytes should be width (800.0) and height (600.0) as floats
    unpacked = data[0, 8].unpack("ff")
    assert_in_delta 800.0, unpacked[0], 0.01
    assert_in_delta 600.0, unpacked[1], 0.01
  end
end

class MSLTranslatorTest < Test::Unit::TestCase
  test "translate removes static keyword" do
    translator = RLSL::MSL::Translator.new({}, "static float x = 1.0;", "")
    result = translator.translate

    assert_false result.include?("static float")
  end

  test "translate removes inline keyword" do
    translator = RLSL::MSL::Translator.new({}, "inline float helper() { return 1.0; }", "")
    result = translator.translate

    assert_false result.include?("inline float")
  end

  test "generates uniform struct with resolution" do
    translator = RLSL::MSL::Translator.new({ time: :float }, "", "")
    result = translator.translate

    assert result.include?("float2 resolution;")
    assert result.include?("float time;")
  end

  test "generates compute kernel" do
    translator = RLSL::MSL::Translator.new({}, "", "return float3(1.0);")
    result = translator.translate

    assert result.include?("kernel void compute_shader")
    assert result.include?("texture2d<float, access::write> output")
  end

  test "target types are Metal types" do
    translator = RLSL::MSL::Translator.new({}, "", "")

    assert_equal "float2", translator.send(:target_vec2_type)
    assert_equal "float3", translator.send(:target_vec3_type)
    assert_equal "float4", translator.send(:target_vec4_type)
  end

  test "translates C to MSL with headers" do
    uniforms = { time: :float }
    helpers = "static inline float helper(float x) { return x * 2.0f; }"
    fragment = "return vec3_new(1.0f, 0.0f, 0.0f);"

    translator = RLSL::MSL::Translator.new(uniforms, helpers, fragment)
    msl = translator.translate

    assert msl.include?("#include <metal_stdlib>")
    assert msl.include?("using namespace metal;")
    assert msl.include?("struct Uniforms")
    assert msl.include?("float time;")
    assert msl.include?("kernel void compute_shader")
  end

  test "replaces vec2_new with float2" do
    translator = RLSL::MSL::Translator.new({}, "", "vec2_new(1.0f, 2.0f)")
    msl = translator.translate
    assert msl.include?("float2(1.0f, 2.0f)")
  end

  test "replaces vec3_new with float3" do
    translator = RLSL::MSL::Translator.new({}, "", "vec3_new(1.0f, 2.0f, 3.0f)")
    msl = translator.translate
    assert msl.include?("float3(1.0f, 2.0f, 3.0f)")
  end

  test "replaces math functions" do
    translator = RLSL::MSL::Translator.new({}, "", "sqrtf(x) sinf(y) cosf(z)")
    msl = translator.translate
    assert msl.include?("sqrt(x)")
    assert msl.include?("sin(y)")
    assert msl.include?("cos(z)")
  end

  test "handles empty code" do
    translator = RLSL::MSL::Translator.new({}, nil, nil)
    msl = translator.translate
    assert msl.include?("kernel void compute_shader")
  end

  test "generates proper uniform types" do
    uniforms = { time: :float, mouse: :vec2, pos: :vec3, color: :vec4 }
    translator = RLSL::MSL::Translator.new(uniforms, "", "")
    msl = translator.translate

    assert msl.include?("float time;")
    assert msl.include?("float2 mouse;")
    assert msl.include?("float3 pos;")
    assert msl.include?("float4 color;")
  end
end

class WGSLTranslatorTest < Test::Unit::TestCase
  test "translate removes static keyword" do
    translator = RLSL::WGSL::Translator.new({}, "static float x = 1.0;", "")
    result = translator.translate

    assert_false result.include?("static f32")
  end

  test "translate removes inline keyword" do
    translator = RLSL::WGSL::Translator.new({}, "inline float helper() { return 1.0; }", "")
    result = translator.translate

    assert_false result.include?("inline f32")
  end

  test "translate replaces float with f32" do
    translator = RLSL::WGSL::Translator.new({}, "float x = 1.0;", "float y = 2.0;")
    result = translator.translate

    assert result.include?("f32 x = 1.0;")
    assert result.include?("f32 y = 2.0;")
  end

  test "generates uniform struct with resolution" do
    translator = RLSL::WGSL::Translator.new({ time: :float }, "", "")
    result = translator.translate

    assert result.include?("resolution: vec2<f32>,")
    assert result.include?("time: f32,")
  end

  test "generates compute shader with workgroup" do
    translator = RLSL::WGSL::Translator.new({}, "", "return vec3<f32>(1.0);")
    result = translator.translate

    assert result.include?("@compute @workgroup_size(8, 8)")
    assert result.include?("fn main")
  end

  test "target_float_type returns f32" do
    translator = RLSL::WGSL::Translator.new({}, "", "")
    assert_equal "f32", translator.send(:target_float_type)
  end

  test "target types are WGSL types" do
    translator = RLSL::WGSL::Translator.new({}, "", "")

    assert_equal "vec2<f32>", translator.send(:target_vec2_type)
    assert_equal "vec3<f32>", translator.send(:target_vec3_type)
    assert_equal "vec4<f32>", translator.send(:target_vec4_type)
  end
end

class GLSLTranslatorTest < Test::Unit::TestCase
  test "initializes with custom version" do
    translator = RLSL::GLSL::Translator.new({}, "", "", version: "430")
    result = translator.translate

    assert result.include?("#version 430")
  end

  test "default version is 450" do
    translator = RLSL::GLSL::Translator.new({}, "", "")
    result = translator.translate

    assert result.include?("#version 450")
  end

  test "translate removes static keyword" do
    translator = RLSL::GLSL::Translator.new({}, "static float x = 1.0;", "")
    result = translator.translate

    assert_false result.include?("static float")
  end

  test "translate removes inline keyword" do
    translator = RLSL::GLSL::Translator.new({}, "inline float helper() { return 1.0; }", "")
    result = translator.translate

    assert_false result.include?("inline float")
  end

  test "generates uniform block with resolution" do
    translator = RLSL::GLSL::Translator.new({ time: :float }, "", "")
    result = translator.translate

    assert result.include?("layout(binding = 1) uniform ShaderUniforms")
    assert result.include?("vec2 resolution;")
    assert result.include?("float time;")
  end

  test "generates compute shader with local size" do
    translator = RLSL::GLSL::Translator.new({}, "", "return vec3(1.0);")
    result = translator.translate

    assert result.include?("layout(local_size_x = 8, local_size_y = 8) in;")
    assert result.include?("void main()")
  end

  test "generates image output" do
    translator = RLSL::GLSL::Translator.new({}, "", "")
    result = translator.translate

    assert result.include?("layout(rgba8, binding = 0) uniform writeonly image2D outputImage")
  end

  test "target types are GLSL types" do
    translator = RLSL::GLSL::Translator.new({}, "", "")

    assert_equal "vec2", translator.send(:target_vec2_type)
    assert_equal "vec3", translator.send(:target_vec3_type)
    assert_equal "vec4", translator.send(:target_vec4_type)
  end
end
