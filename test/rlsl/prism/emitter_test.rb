# frozen_string_literal: true

require_relative "../../test_helper"

class BaseEmitterTest < Test::Unit::TestCase
  def setup
    @emitter = RLSL::Prism::Emitters::CEmitter.new
  end

  test "PRECEDENCE constant defined" do
    prec = RLSL::Prism::Emitters::BaseEmitter::PRECEDENCE
    assert prec.key?("||")
    assert prec.key?("&&")
    assert prec.key?("+")
    assert prec.key?("*")
  end

  test "emit_block with empty statements" do
    block = RLSL::Prism::IR::Block.new([])
    result = @emitter.send(:emit_block, block)
    assert_equal "", result
  end

  test "emit_block with needs_return" do
    block = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Literal.new(1.0, :float)
    ])
    result = @emitter.send(:emit_block, block, needs_return: true)
    assert result.include?("return 1.0f")
  end

  test "emit_function_definition with params" do
    body = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(RLSL::Prism::IR::VarRef.new(:x))
    ])
    func = RLSL::Prism::IR::FunctionDefinition.new(
      :helper,
      [:x, :y],
      body,
      return_type: :float,
      param_types: { x: :float, y: :float }
    )

    result = @emitter.emit(func)
    assert result.include?("static inline float helper")
    assert result.include?("float x")
    assert result.include?("float y")
  end

  test "emit_function_definition with array return type" do
    body = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(
        RLSL::Prism::IR::ArrayLiteral.new([
          RLSL::Prism::IR::Literal.new(1.0, :float),
          RLSL::Prism::IR::Literal.new(2.0, :float)
        ])
      )
    ])
    func = RLSL::Prism::IR::FunctionDefinition.new(
      :multi_return,
      [],
      body,
      return_type: [:float, :float]
    )

    result = @emitter.emit(func)
    assert result.include?("typedef struct")
    assert result.include?("multi_return_result")
  end

  test "emit_global_decl with array" do
    elements = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float),
      RLSL::Prism::IR::Literal.new(3.0, :float)
    ]
    init = RLSL::Prism::IR::ArrayLiteral.new(elements)
    decl = RLSL::Prism::IR::GlobalDecl.new(
      :MY_ARRAY,
      init,
      type: nil,
      is_const: true,
      is_static: true,
      array_size: 3,
      element_type: :float
    )

    result = @emitter.emit(decl)
    assert result.include?("static const float MY_ARRAY[3]")
  end

  test "emit_global_decl with scalar" do
    init = RLSL::Prism::IR::Literal.new(42.0, :float)
    decl = RLSL::Prism::IR::GlobalDecl.new(
      :MY_CONST,
      init,
      type: :float,
      is_const: true,
      is_static: true
    )

    result = @emitter.emit(decl)
    assert result.include?("static const float MY_CONST")
  end

  test "emit_multiple_assignment with func call" do
    func_call = RLSL::Prism::IR::FuncCall.new(:get_pair, [])
    targets = [
      RLSL::Prism::IR::VarRef.new(:a, :float),
      RLSL::Prism::IR::VarRef.new(:b, :float)
    ]
    assign = RLSL::Prism::IR::MultipleAssignment.new(targets, func_call)

    result = @emitter.emit(assign)
    assert result.include?("get_pair_result")
    assert result.include?("float a")
    assert result.include?("float b")
  end

  test "emit_multiple_assignment with array" do
    array = RLSL::Prism::IR::VarRef.new(:arr)
    targets = [
      RLSL::Prism::IR::VarRef.new(:x, :float),
      RLSL::Prism::IR::VarRef.new(:y, :float)
    ]
    assign = RLSL::Prism::IR::MultipleAssignment.new(targets, array)

    result = @emitter.emit(assign)
    assert result.include?("float x = arr[0]")
    assert result.include?("float y = arr[1]")
  end

  test "emit_array_literal" do
    elements = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float)
    ]
    array = RLSL::Prism::IR::ArrayLiteral.new(elements)

    result = @emitter.emit(array)
    assert_equal "{1.0f, 2.0f}", result
  end

  test "emit_array_index with literal index" do
    array = RLSL::Prism::IR::VarRef.new(:arr)
    index = RLSL::Prism::IR::Literal.new(0, :int)
    access = RLSL::Prism::IR::ArrayIndex.new(array, index)

    result = @emitter.emit(access)
    assert_equal "arr[0]", result
  end

  test "emit_array_index with variable index" do
    array = RLSL::Prism::IR::VarRef.new(:arr)
    index = RLSL::Prism::IR::VarRef.new(:i)
    access = RLSL::Prism::IR::ArrayIndex.new(array, index)

    result = @emitter.emit(access)
    assert_equal "arr[i]", result
  end

  test "emit_with_return for if statement" do
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    then_branch = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Literal.new(1.0, :float)
    ])
    else_branch = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Literal.new(0.0, :float)
    ])
    if_stmt = RLSL::Prism::IR::IfStatement.new(condition, then_branch, else_branch)

    result = @emitter.send(:emit_with_return, if_stmt)
    assert result.include?("if (1)")
    assert result.include?("return 1.0f")
    assert result.include?("return 0.0f")
  end

  test "emit_with_return for global decl" do
    init = RLSL::Prism::IR::Literal.new(1.0, :float)
    decl = RLSL::Prism::IR::GlobalDecl.new(:X, init)

    result = @emitter.send(:emit_with_return, decl)
    # Global decls don't get return wrapped
    assert result.include?("X")
  end

  test "emit_for_static_init with vec3" do
    vec_call = RLSL::Prism::IR::FuncCall.new(:vec3, [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float)
    ])

    result = @emitter.send(:emit_for_static_init, vec_call, true)
    assert_equal "{1.0f, 0.0f, 0.0f}", result
  end

  test "emit_for_static_init with regular node" do
    lit = RLSL::Prism::IR::Literal.new(1.0, :float)

    result = @emitter.send(:emit_for_static_init, lit, true)
    assert_equal "1.0f", result
  end

  test "emit_elsif chain" do
    condition1 = RLSL::Prism::IR::BinaryOp.new(">", RLSL::Prism::IR::VarRef.new(:x), RLSL::Prism::IR::Literal.new(0.0))
    condition2 = RLSL::Prism::IR::BinaryOp.new("<", RLSL::Prism::IR::VarRef.new(:x), RLSL::Prism::IR::Literal.new(0.0))

    then1 = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(1.0))])
    then2 = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(-1.0))])
    else_final = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(0.0))])

    elsif_stmt = RLSL::Prism::IR::IfStatement.new(condition2, then2, else_final)
    if_stmt = RLSL::Prism::IR::IfStatement.new(condition1, then1, elsif_stmt)

    result = @emitter.emit(if_stmt)
    assert result.include?("if (x > 0.0f)")
    assert result.include?("else if (x < 0.0f)")
    assert result.include?("else {")
  end

  test "format_number with integer" do
    result = @emitter.send(:format_number, 1)
    assert_equal "1.0f", result
  end

  test "format_number with float" do
    result = @emitter.send(:format_number, 1.5)
    assert_equal "1.5f", result
  end

  test "indent at different levels" do
    assert_equal "", @emitter.send(:indent)

    @emitter.instance_variable_set(:@indent_level, 1)
    assert_equal "  ", @emitter.send(:indent)

    @emitter.instance_variable_set(:@indent_level, 2)
    assert_equal "    ", @emitter.send(:indent)
  end

  test "current_return_struct_name default" do
    result = @emitter.send(:current_return_struct_name)
    assert_equal "result", result
  end

  test "function_name returns string" do
    result = @emitter.send(:function_name, :my_func)
    assert_equal "my_func", result
  end
end

class EmitterIntegrationTest < Test::Unit::TestCase
  test "full shader transpilation" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float })
    source = <<~RUBY
      x = sin(u.time)
      y = cos(u.time)
      color = vec3(x, y, 0.5)
      return color
    RUBY

    code = transpiler.transpile_source(source, :c)
    assert code.include?("sinf")
    assert code.include?("cosf")
    assert code.include?("vec3_new")
  end

  test "MSL emitter uses float types" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float })
    source = <<~RUBY
      color = vec3(1.0, 0.0, 0.0)
      return color
    RUBY

    code = transpiler.transpile_source(source, :msl)
    assert code.include?("float3")
    assert_false code.include?("vec3_new")
  end

  test "WGSL emitter uses f32 types" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float })
    source = <<~RUBY
      color = vec3(1.0, 0.0, 0.0)
      return color
    RUBY

    code = transpiler.transpile_source(source, :wgsl)
    assert code.include?("vec3<f32>")
    assert code.include?("let color")
  end

  test "GLSL emitter uses vec3" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float })
    source = <<~RUBY
      color = vec3(1.0, 0.0, 0.0)
      return color
    RUBY

    code = transpiler.transpile_source(source, :glsl)
    assert code.include?("vec3(")
  end
end

class EmitterTypeMapTest < Test::Unit::TestCase
  test "GLSL emitter TYPE_MAP includes matrix types" do
    type_map = RLSL::Prism::Emitters::GLSLEmitter::TYPE_MAP
    assert_equal "mat2", type_map[:mat2]
    assert_equal "mat3", type_map[:mat3]
    assert_equal "mat4", type_map[:mat4]
    assert_equal "sampler2D", type_map[:sampler2D]
  end

  test "WGSL emitter TYPE_MAP includes matrix types" do
    type_map = RLSL::Prism::Emitters::WGSLEmitter::TYPE_MAP
    assert_equal "mat2x2<f32>", type_map[:mat2]
    assert_equal "mat3x3<f32>", type_map[:mat3]
    assert_equal "mat4x4<f32>", type_map[:mat4]
    assert_equal "texture_2d<f32>", type_map[:sampler2D]
  end

  test "MSL emitter TYPE_MAP includes matrix types" do
    type_map = RLSL::Prism::Emitters::MSLEmitter::TYPE_MAP
    assert_equal "float2x2", type_map[:mat2]
    assert_equal "float3x3", type_map[:mat3]
    assert_equal "float4x4", type_map[:mat4]
    assert_equal "texture2d<float>", type_map[:sampler2D]
  end

  test "C emitter TYPE_MAP includes matrix types" do
    type_map = RLSL::Prism::Emitters::CEmitter::TYPE_MAP
    assert_equal "mat2", type_map[:mat2]
    assert_equal "mat3", type_map[:mat3]
    assert_equal "mat4", type_map[:mat4]
    assert_equal "sampler2D", type_map[:sampler2D]
  end

  test "GLSL emitter MATRIX_CONSTRUCTORS defined" do
    constructors = RLSL::Prism::Emitters::GLSLEmitter::MATRIX_CONSTRUCTORS
    assert_equal "mat2", constructors[:mat2]
    assert_equal "mat3", constructors[:mat3]
    assert_equal "mat4", constructors[:mat4]
  end

  test "WGSL emitter MATRIX_CONSTRUCTORS defined" do
    constructors = RLSL::Prism::Emitters::WGSLEmitter::MATRIX_CONSTRUCTORS
    assert_equal "mat2x2<f32>", constructors[:mat2]
    assert_equal "mat3x3<f32>", constructors[:mat3]
    assert_equal "mat4x4<f32>", constructors[:mat4]
  end

  test "MSL emitter MATRIX_CONSTRUCTORS defined" do
    constructors = RLSL::Prism::Emitters::MSLEmitter::MATRIX_CONSTRUCTORS
    assert_equal "float2x2", constructors[:mat2]
    assert_equal "float3x3", constructors[:mat3]
    assert_equal "float4x4", constructors[:mat4]
  end

  test "C emitter MATRIX_CONSTRUCTORS defined" do
    constructors = RLSL::Prism::Emitters::CEmitter::MATRIX_CONSTRUCTORS
    assert_equal "mat2_new", constructors[:mat2]
    assert_equal "mat3_new", constructors[:mat3]
    assert_equal "mat4_new", constructors[:mat4]
  end

  test "GLSL emitter TEXTURE_FUNCTIONS defined" do
    funcs = RLSL::Prism::Emitters::GLSLEmitter::TEXTURE_FUNCTIONS
    assert_equal "texture2D", funcs[:texture2D]
    assert_equal "texture", funcs[:texture]
    assert_equal "textureLod", funcs[:textureLod]
  end

  test "WGSL emitter TEXTURE_FUNCTIONS defined" do
    funcs = RLSL::Prism::Emitters::WGSLEmitter::TEXTURE_FUNCTIONS
    assert_equal "textureSample", funcs[:texture2D]
    assert_equal "textureSample", funcs[:texture]
    assert_equal "textureSampleLevel", funcs[:textureLod]
  end

  test "MSL emitter TEXTURE_FUNCTIONS defined" do
    funcs = RLSL::Prism::Emitters::MSLEmitter::TEXTURE_FUNCTIONS
    assert_equal "sample", funcs[:texture2D]
    assert_equal "sample", funcs[:texture]
    assert_equal "sample", funcs[:textureLod]
  end

  test "C emitter TEXTURE_FUNCTIONS defined" do
    funcs = RLSL::Prism::Emitters::CEmitter::TEXTURE_FUNCTIONS
    assert_equal "texture_sample", funcs[:texture2D]
    assert_equal "texture_sample", funcs[:texture]
    assert_equal "texture_sample_lod", funcs[:textureLod]
  end
end
