# frozen_string_literal: true

require_relative "../test_helper"

class CodeGeneratorTest < Test::Unit::TestCase
  test "generates vec4 uniform" do
    uniforms = { color: :vec4 }
    gen = RLSL::CodeGenerator.new(:test, uniforms, nil, -> { "return vec3_new(1.0f, 0.0f, 0.0f);" })
    code = gen.generate

    assert code.include?("vec4 color;")
  end

  test "generates all uniform types in one struct" do
    uniforms = { time: :float, pos2d: :vec2, pos3d: :vec3, color: :vec4 }
    gen = RLSL::CodeGenerator.new(:test, uniforms, nil, -> { "return vec3_new(1.0f, 0.0f, 0.0f);" })
    code = gen.generate

    assert code.include?("float time;")
    assert code.include?("vec2 pos2d;")
    assert code.include?("vec3 pos3d;")
    assert code.include?("vec4 color;")
  end

  test "generates Init function with RLSL module" do
    gen = RLSL::CodeGenerator.new(:my_shader, {}, nil, -> { "return vec3_new(1.0f, 0.0f, 0.0f);" })
    code = gen.generate

    assert code.include?('VALUE mRLSL = rb_define_module("RLSL");')
    assert code.include?('VALUE mShaders = rb_define_module_under(mRLSL, "CompiledShaders");')
    assert code.include?("Init_my_shader")
  end

  test "includes math helpers" do
    gen = RLSL::CodeGenerator.new(:test, {}, nil, -> { "" })
    code = gen.generate

    assert code.include?("vec2_new")
    assert code.include?("vec3_new")
    assert code.include?("vec4_new")
    assert code.include?("vec2_add")
    assert code.include?("vec3_add")
    assert code.include?("fract")
    assert code.include?("smoothstep")
  end

  test "includes reflect and refract functions" do
    gen = RLSL::CodeGenerator.new(:test, {}, nil, -> { "" })
    code = gen.generate

    assert code.include?("static inline vec3 reflect")
    assert code.include?("static inline vec3 refract")
  end

  test "includes hash functions" do
    gen = RLSL::CodeGenerator.new(:test, {}, nil, -> { "" })
    code = gen.generate

    assert code.include?("hash21")
    assert code.include?("hash22")
  end

  test "generates vec2 uniform parsing" do
    uniforms = { pos: :vec2 }
    gen = RLSL::CodeGenerator.new(:test, uniforms, nil, -> { "" })
    code = gen.generate

    assert code.include?("Check_Type(rb_pos, T_ARRAY)")
    assert code.include?("rb_ary_entry(rb_pos, 0)")
    assert code.include?("rb_ary_entry(rb_pos, 1)")
  end

  test "generates vec3 uniform parsing" do
    uniforms = { color: :vec3 }
    gen = RLSL::CodeGenerator.new(:test, uniforms, nil, -> { "" })
    code = gen.generate

    assert code.include?("Check_Type(rb_color, T_ARRAY)")
    assert code.include?("rb_ary_entry(rb_color, 0)")
    assert code.include?("rb_ary_entry(rb_color, 1)")
    assert code.include?("rb_ary_entry(rb_color, 2)")
  end

  test "generates float uniform parsing" do
    uniforms = { time: :float }
    gen = RLSL::CodeGenerator.new(:test, uniforms, nil, -> { "" })
    code = gen.generate

    assert code.include?("uniforms.time = (float)NUM2DBL(rb_time);")
  end

  test "generates Apple-specific parallel dispatch" do
    gen = RLSL::CodeGenerator.new(:test, {}, nil, -> { "" })
    code = gen.generate

    assert code.include?("#ifdef __APPLE__")
    assert code.include?("dispatch_apply")
  end

  test "generates shader function" do
    gen = RLSL::CodeGenerator.new(:my_shader, {}, nil, -> { "return vec3_new(1.0f, 0.0f, 0.0f);" })
    code = gen.generate

    assert code.include?("static vec3 shader_my_shader(vec2 frag_coord, vec2 resolution, Uniforms u)")
  end

  test "includes custom helpers in generated code" do
    helpers = -> { "// Custom helper function\nstatic float my_helper(float x) { return x * 2.0f; }" }
    gen = RLSL::CodeGenerator.new(:test, {}, helpers, -> { "" })
    code = gen.generate

    assert code.include?("Custom helper function")
    assert code.include?("my_helper")
  end

  test "generates correct argument count for render function" do
    uniforms = { time: :float, scale: :float }
    gen = RLSL::CodeGenerator.new(:test, uniforms, nil, -> { "" })
    code = gen.generate

    # 3 base args + 2 uniforms = 5
    assert code.include?(", 5)")
  end

  test "generates BGRA pixel output" do
    gen = RLSL::CodeGenerator.new(:test, {}, nil, -> { "" })
    code = gen.generate

    assert code.include?("// Output as BGRA")
    # Blue channel first (color.z)
    assert code.include?("color.z")
  end

  test "generates C code with helpers and fragment" do
    uniforms = { time: :float }
    helpers_block = -> { "// Custom helper" }
    fragment_block = -> { "return vec3_new(1.0, 0.0, 0.0);" }

    gen = RLSL::CodeGenerator.new(:test, uniforms, helpers_block, fragment_block)
    code = gen.generate

    assert code.include?("#include <ruby.h>")
    assert code.include?("typedef struct")
    assert code.include?("float time;")
    assert code.include?("shader_test")
    assert code.include?("Init_test")
  end

  test "handles empty uniforms" do
    gen = RLSL::CodeGenerator.new(:test, {}, nil, -> { "" })
    code = gen.generate
    assert code.include?("typedef struct {} Uniforms;")
  end

  test "generates vec2 uniform in struct" do
    uniforms = { mouse: :vec2 }
    gen = RLSL::CodeGenerator.new(:test, uniforms, nil, -> { "" })
    code = gen.generate
    assert code.include?("vec2 mouse;")
  end

  test "generates vec3 uniform in struct" do
    uniforms = { pos: :vec3 }
    gen = RLSL::CodeGenerator.new(:test, uniforms, nil, -> { "" })
    code = gen.generate
    assert code.include?("vec3 pos;")
  end
end
