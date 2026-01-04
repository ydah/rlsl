# frozen_string_literal: true

require_relative "../test_helper"

class ShaderBuilderFunctionsTest < Test::Unit::TestCase
  test "functions block registers custom functions" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.functions do
      float :helper1
      vec3 :get_color
    end

    custom_funcs = builder.instance_variable_get(:@custom_functions)
    assert_equal({ returns: :float }, custom_funcs[:helper1])
    assert_equal({ returns: :vec3 }, custom_funcs[:get_color])
  end

  test "functions block with define" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.functions do
      define :complex_func, returns: :vec3, params: { x: :float }
    end

    custom_funcs = builder.instance_variable_get(:@custom_functions)
    expected = { returns: :vec3, params: { x: :float } }
    assert_equal expected, custom_funcs[:complex_func]
  end
end

class ShaderBuilderHelpersModeTest < Test::Unit::TestCase
  test "helpers_ruby_mode? returns false by default" do
    builder = RLSL::ShaderBuilder.new(:test)
    assert_false builder.helpers_ruby_mode?
  end

  test "helpers_ruby_mode? returns true for ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.helpers(:ruby) { "some helper" }
    assert_true builder.helpers_ruby_mode?
  end

  test "helpers_ruby_mode? returns false for c mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.helpers(:c) { "some helper" }
    assert_false builder.helpers_ruby_mode?
  end

  test "helpers sets block and mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.helpers(:ruby) { "helper code" }

    block = builder.instance_variable_get(:@helpers_block)
    mode = builder.instance_variable_get(:@helpers_mode)

    assert_not_nil block
    assert_equal :ruby, mode
  end
end

class ShaderBuilderTranspileTest < Test::Unit::TestCase
  test "transpile_fragment returns empty string without fragment block" do
    builder = RLSL::ShaderBuilder.new(:test)
    result = builder.transpile_fragment(:c)
    assert_equal "", result
  end

  test "transpile_helpers returns empty string without helpers block" do
    builder = RLSL::ShaderBuilder.new(:test)
    result = builder.transpile_helpers(:c)
    assert_equal "", result
  end

  test "transpile_fragment with ruby block" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    result = builder.transpile_fragment(:c)
    assert result.include?("vec3_new")
  end

  test "transpile_fragment to different targets" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    c_result = builder.transpile_fragment(:c)
    msl_result = builder.transpile_fragment(:msl)
    wgsl_result = builder.transpile_fragment(:wgsl)
    glsl_result = builder.transpile_fragment(:glsl)

    assert c_result.include?("vec3_new")
    assert msl_result.include?("float3")
    assert wgsl_result.include?("vec3<f32>")
    assert glsl_result.include?("vec3")
  end
end

class ShaderBuilderBuildMethodsRubyModeTest < Test::Unit::TestCase
  test "build_metal_shader in ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_metal)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    shader = builder.build_metal_shader
    assert_kind_of RLSL::MSL::Shader, shader
    assert shader.msl_source.include?("float3")
  end

  test "build_wgsl_shader in ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_wgsl)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    wgsl = builder.build_wgsl_shader
    assert wgsl.include?("vec3<f32>")
  end

  test "build_glsl_shader in ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test_ruby_glsl)
    builder.uniforms { float :time }
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }

    glsl = builder.build_glsl_shader
    assert glsl.include?("vec3")
  end

  test "build_metal_shader with helpers" do
    builder = RLSL::ShaderBuilder.new(:test_with_helpers)
    builder.uniforms { float :time }
    builder.helpers(:c) { "// custom helper" }
    builder.fragment { "return vec3_new(1.0f, 0.0f, 0.0f);" }

    shader = builder.build_metal_shader
    assert_kind_of RLSL::MSL::Shader, shader
  end

  test "build_wgsl_shader with helpers" do
    builder = RLSL::ShaderBuilder.new(:test_wgsl_helpers)
    builder.uniforms { float :time }
    builder.helpers(:c) { "// custom helper" }
    builder.fragment { "return vec3_new(1.0f, 0.0f, 0.0f);" }

    wgsl = builder.build_wgsl_shader
    assert_kind_of String, wgsl
  end

  test "build_glsl_shader with helpers" do
    builder = RLSL::ShaderBuilder.new(:test_glsl_helpers)
    builder.uniforms { float :time }
    builder.helpers(:c) { "// custom helper" }
    builder.fragment { "return vec3_new(1.0f, 0.0f, 0.0f);" }

    glsl = builder.build_glsl_shader
    assert_kind_of String, glsl
  end
end

class ShaderBuilderFragmentModeTest < Test::Unit::TestCase
  test "fragment with no args sets C mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.fragment { "C code" }
    assert_equal :c, builder.instance_variable_get(:@fragment_mode)
  end

  test "fragment with args sets Ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.fragment { |frag_coord| vec3(1.0, 0.0, 0.0) }
    assert_equal :ruby, builder.instance_variable_get(:@fragment_mode)
  end

  test "fragment with multiple args sets Ruby mode" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }
    assert_equal :ruby, builder.instance_variable_get(:@fragment_mode)
  end
end

class ShaderBuilderCoreTest < Test::Unit::TestCase
  test "initializes with name" do
    builder = RLSL::ShaderBuilder.new(:test)
    assert_equal "test", builder.name
  end

  test "uniforms block defines uniforms" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.uniforms do
      float :time
      vec2 :mouse
    end
    uniforms = builder.uniforms
    assert_equal :float, uniforms[:time]
    assert_equal :vec2, uniforms[:mouse]
  end

  test "helpers block is stored" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.helpers(:c) { "// Helper code" }
  end

  test "fragment block is stored" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.fragment { "return vec3_new(1.0, 0.0, 0.0);" }
  end

  test "build_metal_shader creates MSL::Shader" do
    builder = RLSL::ShaderBuilder.new(:test_metal)
    builder.uniforms { float :time }
    builder.helpers(:c) { "" }
    builder.fragment { "return float3(1.0, 0.0, 0.0);" }

    shader = builder.build_metal_shader
    assert_kind_of RLSL::MSL::Shader, shader
  end

  test "build_wgsl_shader returns WGSL source" do
    builder = RLSL::ShaderBuilder.new(:test_wgsl)
    builder.uniforms { float :time }
    builder.helpers(:c) { "" }
    builder.fragment { "return vec3_new(1.0, 0.0, 0.0);" }

    wgsl = builder.build_wgsl_shader
    assert_kind_of String, wgsl
    assert wgsl.include?("@compute")
  end

  test "build_glsl_shader returns GLSL source" do
    builder = RLSL::ShaderBuilder.new(:test_glsl)
    builder.uniforms { float :time }
    builder.helpers(:c) { "" }
    builder.fragment { "return vec3_new(1.0, 0.0, 0.0);" }

    glsl = builder.build_glsl_shader
    assert_kind_of String, glsl
    assert glsl.include?("#version 450")
  end
end
