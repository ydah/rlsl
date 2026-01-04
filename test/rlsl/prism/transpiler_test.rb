# frozen_string_literal: true

require_relative "../../test_helper"

class PrismTranspilerTest < Test::Unit::TestCase
  def setup
    @transpiler = RLSL::Prism::Transpiler.new({ time: :float })
  end

  test "parse simple variable declaration" do
    source = "x = 1.0\nreturn x"
    ir = @transpiler.parse_source(source)

    assert_kind_of RLSL::Prism::IR::Block, ir
    assert_equal 2, ir.statements.length
    assert_kind_of RLSL::Prism::IR::VarDecl, ir.statements.first
  end

  test "parse binary operation" do
    source = "x = 1.0 + 2.0\nreturn x"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::VarDecl, stmt
    assert_kind_of RLSL::Prism::IR::BinaryOp, stmt.initializer
    assert_equal "+", stmt.initializer.operator
  end

  test "parse function call" do
    source = "x = sin(0.5)\nreturn x"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :sin, stmt.initializer.name
  end

  test "parse vec3 constructor" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :vec3, stmt.initializer.name
    assert_equal 3, stmt.initializer.args.length
  end

  test "parse field access" do
    source = "x = v.x\nreturn x"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FieldAccess, stmt.initializer
    assert_equal "x", stmt.initializer.field
  end

  test "emit to C" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    code = @transpiler.transpile_source(source, :c)

    assert code.include?("vec3_new")
    assert code.include?("return color")
  end

  test "emit to MSL" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    code = @transpiler.transpile_source(source, :msl)

    assert code.include?("float3")
    assert code.include?("return color")
  end

  test "emit to WGSL" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    code = @transpiler.transpile_source(source, :wgsl)

    assert code.include?("vec3<f32>")
    assert code.include?("let color")
  end

  test "emit to GLSL" do
    source = "color = vec3(1.0, 0.0, 0.0)\nreturn color"
    code = @transpiler.transpile_source(source, :glsl)

    assert code.include?("vec3")
    assert code.include?("return color")
  end

  test "type inference for vec3" do
    source = "color = vec3(1.0, 0.0, 0.0)"
    ir = @transpiler.parse_source(source)

    stmt = ir.statements.first
    assert_equal :vec3, stmt.type
  end

  test "type inference for binary op with vectors" do
    source = <<~RUBY
      a = vec2(1.0, 2.0)
      b = a + a
    RUBY
    ir = @transpiler.parse_source(source)

    # Second statement should be vec2 type
    assert_equal :vec2, ir.statements[1].type
  end

  test "TARGETS constant contains all emitters" do
    targets = RLSL::Prism::Transpiler::TARGETS
    assert_equal RLSL::Prism::Emitters::CEmitter, targets[:c]
    assert_equal RLSL::Prism::Emitters::MSLEmitter, targets[:msl]
    assert_equal RLSL::Prism::Emitters::WGSLEmitter, targets[:wgsl]
    assert_equal RLSL::Prism::Emitters::GLSLEmitter, targets[:glsl]
  end

  test "initialize stores uniforms and custom_functions" do
    transpiler = RLSL::Prism::Transpiler.new({ time: :float }, { helper: { returns: :float } })
    assert_equal({ time: :float }, transpiler.uniforms)
    assert_equal({ helper: { returns: :float } }, transpiler.custom_functions)
  end

  test "emit raises error without parsing first" do
    transpiler = RLSL::Prism::Transpiler.new
    assert_raise(RuntimeError) do
      transpiler.emit(:c)
    end
  end

  test "emit raises error for unknown target" do
    @transpiler.parse_source("x = 1.0\nreturn x")
    assert_raise(RuntimeError) do
      @transpiler.emit(:unknown_target)
    end
  end

  test "emit accepts target as string" do
    @transpiler.parse_source("x = 1.0\nreturn x")
    result = @transpiler.emit("c")
    assert_kind_of String, result
  end

  test "transpile_source combines parse and emit" do
    result = @transpiler.transpile_source("x = 1.0\nreturn x", :c)
    assert result.include?("1.0f")
  end

  test "parse_source registers frag_coord and resolution" do
    @transpiler.parse_source("return frag_coord")
    # Should not raise - frag_coord is registered
    result = @transpiler.emit(:c)
    assert result.include?("frag_coord")
  end

  test "parse_source handles empty body" do
    @transpiler.parse_source("return 0.0")
    result = @transpiler.emit(:c)
    assert result.include?("return 0.0f")
  end

  test "emit with needs_return false" do
    @transpiler.parse_source("x = 1.0\nreturn x")
    result = @transpiler.emit(:c, needs_return: false)
    assert_kind_of String, result
  end
end

class PrismTranspilerExtractBlockBodyTest < Test::Unit::TestCase
  def setup
    @transpiler = RLSL::Prism::Transpiler.new
  end

  test "extract_block_body with parameters" do
    source = "|x, y|\nx + y"
    params, body = @transpiler.send(:extract_block_body, source)
    assert_equal [:x, :y], params
    assert body.include?("+")
  end

  test "extract_block_body without parameters" do
    source = "x = 1.0\nreturn x"
    params, body = @transpiler.send(:extract_block_body, source)
    assert_equal [], params
    assert body.include?("x = 1.0")
  end

  test "extract_block_body trims empty lines" do
    source = "\n\n  x = 1.0  \n\n"
    params, body = @transpiler.send(:extract_block_body, source)
    assert_equal "x = 1.0", body.strip
  end

  test "extract_block_body handles single line" do
    source = "return 1.0"
    params, body = @transpiler.send(:extract_block_body, source)
    assert_equal [], params
    assert_equal "return 1.0", body
  end
end

class PrismTranspilerHelpersTest < Test::Unit::TestCase
  test "transpile_helpers with function signatures" do
    transpiler = RLSL::Prism::Transpiler.new(
      { time: :float },
      { helper_func: { returns: :float } }
    )

    # This tests the helper transpilation path
    block = proc do
      x = 1.0
      x
    end

    result = transpiler.transpile_helpers(block, :c, { helper_func: { returns: :float } })
    assert_kind_of String, result
  end
end

class PrismTranspilerApplySignaturesTest < Test::Unit::TestCase
  test "apply_function_signatures does nothing for non-block" do
    transpiler = RLSL::Prism::Transpiler.new

    # Should not raise
    transpiler.send(:apply_function_signatures, nil, {})
    transpiler.send(:apply_function_signatures, RLSL::Prism::IR::Literal.new(1.0), {})
  end

  test "apply_function_signatures updates function definitions" do
    transpiler = RLSL::Prism::Transpiler.new

    func_def = RLSL::Prism::IR::FunctionDefinition.new(
      :my_func,
      [:x],
      RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Return.new(RLSL::Prism::IR::VarRef.new(:x))])
    )
    block = RLSL::Prism::IR::Block.new([func_def])

    signatures = { my_func: { returns: :vec3, params: { x: :float } } }
    transpiler.send(:apply_function_signatures, block, signatures)

    assert_equal :vec3, func_def.return_type
    assert_equal({ x: :float }, func_def.param_types)
  end

  test "apply_function_signatures skips unknown functions" do
    transpiler = RLSL::Prism::Transpiler.new

    func_def = RLSL::Prism::IR::FunctionDefinition.new(
      :unknown_func,
      [],
      RLSL::Prism::IR::Block.new([])
    )
    block = RLSL::Prism::IR::Block.new([func_def])

    # Should not raise
    transpiler.send(:apply_function_signatures, block, { other_func: { returns: :float } })
    assert_nil func_def.return_type
  end
end

class PrismIRNodesTest < Test::Unit::TestCase
  test "Literal node stores value and type" do
    node = RLSL::Prism::IR::Literal.new(1.5, :float)
    assert_equal 1.5, node.value
    assert_equal :float, node.type
  end

  test "VarDecl node stores name and initializer" do
    init = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::VarDecl.new(:x, init, :float)
    assert_equal :x, node.name
    assert_equal init, node.initializer
    assert_equal :float, node.type
  end

  test "BinaryOp node stores operator and operands" do
    left = RLSL::Prism::IR::Literal.new(1.0, :float)
    right = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right)
    assert_equal "+", node.operator
    assert_equal left, node.left
    assert_equal right, node.right
  end

  test "FuncCall node stores name and args" do
    arg = RLSL::Prism::IR::Literal.new(0.5, :float)
    node = RLSL::Prism::IR::FuncCall.new(:sin, [arg])
    assert_equal :sin, node.name
    assert_equal [arg], node.args
  end

  test "Block node stores statements" do
    stmt = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Block.new([stmt])
    assert_equal [stmt], node.statements
  end

  test "ForLoop stores all fields" do
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::ForLoop.new(:i,
      RLSL::Prism::IR::Literal.new(0, :int),
      RLSL::Prism::IR::Literal.new(10, :int),
      body
    )
    assert_equal :i, node.variable
    assert_equal body, node.body
  end

  test "Assignment stores target and value" do
    target = RLSL::Prism::IR::VarRef.new(:x)
    value = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Assignment.new(target, value)
    assert_equal target, node.target
    assert_equal value, node.value
  end

  test "IfStatement stores condition and branches" do
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    then_branch = RLSL::Prism::IR::Block.new([])
    else_branch = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::IfStatement.new(condition, then_branch, else_branch)
    assert_equal condition, node.condition
    assert_equal then_branch, node.then_branch
    assert_equal else_branch, node.else_branch
  end

  test "UnaryOp stores operator and operand" do
    operand = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::UnaryOp.new("-", operand)
    assert_equal "-", node.operator
    assert_equal operand, node.operand
  end

  test "Swizzle stores components" do
    receiver = RLSL::Prism::IR::VarRef.new(:v)
    node = RLSL::Prism::IR::Swizzle.new(receiver, "xyz", :vec3)
    assert_equal "xyz", node.components
    assert_equal :vec3, node.type
  end

  test "Return stores expression" do
    expr = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Return.new(expr)
    assert_equal expr, node.expression
  end

  test "Parenthesized stores expression" do
    expr = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Parenthesized.new(expr)
    assert_equal expr, node.expression
  end

  test "BoolLiteral has bool type" do
    node = RLSL::Prism::IR::BoolLiteral.new(true)
    assert_equal :bool, node.type
  end

  test "WhileLoop stores condition and body" do
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::WhileLoop.new(condition, body)
    assert_equal condition, node.condition
    assert_equal body, node.body
    assert_nil node.type
  end

  test "Break node has nil type" do
    node = RLSL::Prism::IR::Break.new
    assert_nil node.type
  end

  test "Constant stores name and type" do
    node = RLSL::Prism::IR::Constant.new(:PI, :float)
    assert_equal :PI, node.name
    assert_equal :float, node.type
  end
end

class PrismBuiltinsTest < Test::Unit::TestCase
  test "function? returns true for known functions" do
    assert RLSL::Prism::Builtins.function?(:sin)
    assert RLSL::Prism::Builtins.function?(:vec3)
    assert RLSL::Prism::Builtins.function?(:normalize)
  end

  test "function? returns false for unknown functions" do
    assert_false RLSL::Prism::Builtins.function?(:unknown_func)
  end

  test "single_component_field? identifies x, y, z, w" do
    assert RLSL::Prism::Builtins.single_component_field?("x")
    assert RLSL::Prism::Builtins.single_component_field?("y")
    assert RLSL::Prism::Builtins.single_component_field?("z")
    assert RLSL::Prism::Builtins.single_component_field?("w")
  end

  test "swizzle? identifies multi-component access" do
    assert RLSL::Prism::Builtins.swizzle?("xy")
    assert RLSL::Prism::Builtins.swizzle?("xyz")
    assert RLSL::Prism::Builtins.swizzle?("rgba")
  end

  test "swizzle_type returns correct type" do
    assert_equal :vec2, RLSL::Prism::Builtins.swizzle_type("xy")
    assert_equal :vec3, RLSL::Prism::Builtins.swizzle_type("xyz")
    assert_equal :vec4, RLSL::Prism::Builtins.swizzle_type("xyzw")
  end

  test "binary_op_result_type for arithmetic" do
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("+", :vec3, :vec3)
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("*", :vec3, :float)
    assert_equal :float, RLSL::Prism::Builtins.binary_op_result_type("+", :float, :float)
  end

  test "binary_op_result_type for comparison" do
    assert_equal :bool, RLSL::Prism::Builtins.binary_op_result_type("==", :float, :float)
    assert_equal :bool, RLSL::Prism::Builtins.binary_op_result_type("<", :float, :float)
  end

  test "resolve_return_type for normalize returns same vec type" do
    assert_equal :vec2, RLSL::Prism::Builtins.resolve_return_type(:same, [:vec2])
    assert_equal :vec3, RLSL::Prism::Builtins.resolve_return_type(:same, [:vec3])
  end

  test "resolve_return_type for first arg" do
    assert_equal :vec3, RLSL::Prism::Builtins.resolve_return_type(:first, [:vec3, :float])
  end

  test "resolve_return_type for second arg" do
    assert_equal :vec2, RLSL::Prism::Builtins.resolve_return_type(:second, [:float, :vec2])
  end

  test "resolve_return_type for third arg" do
    assert_equal :vec4, RLSL::Prism::Builtins.resolve_return_type(:third, [:float, :float, :vec4])
  end

  test "resolve_return_type for symbol returns symbol" do
    assert_equal :float, RLSL::Prism::Builtins.resolve_return_type(:float, [])
  end

  test "function_signature returns signature" do
    sig = RLSL::Prism::Builtins.function_signature(:sin)
    assert_equal :float, sig[:returns]
  end

  test "function_signature returns nil for unknown" do
    assert_nil RLSL::Prism::Builtins.function_signature(:unknown_func)
  end

  test "binary_operator? returns true for known operators" do
    assert RLSL::Prism::Builtins.binary_operator?("+")
    assert RLSL::Prism::Builtins.binary_operator?("==")
  end

  test "unary_operator? returns true for known operators" do
    assert RLSL::Prism::Builtins.unary_operator?("-")
    assert RLSL::Prism::Builtins.unary_operator?("!")
  end

  test "vector_type? identifies vectors" do
    assert RLSL::Prism::Builtins.vector_type?(:vec2)
    assert RLSL::Prism::Builtins.vector_type?(:vec3)
    assert RLSL::Prism::Builtins.vector_type?(:vec4)
    assert_false RLSL::Prism::Builtins.vector_type?(:float)
  end

  test "scalar_type? identifies scalars" do
    assert RLSL::Prism::Builtins.scalar_type?(:float)
    assert RLSL::Prism::Builtins.scalar_type?(:int)
    assert_false RLSL::Prism::Builtins.scalar_type?(:vec3)
  end

  test "binary_op_result_type for vector-scalar multiplication" do
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("*", :float, :vec3)
  end

  test "binary_op_result_type for vector-vector multiplication" do
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("*", :vec3, :vec3)
  end

  test "function? returns true for matrix constructors" do
    assert RLSL::Prism::Builtins.function?(:mat2)
    assert RLSL::Prism::Builtins.function?(:mat3)
    assert RLSL::Prism::Builtins.function?(:mat4)
  end

  test "function? returns true for matrix functions" do
    assert RLSL::Prism::Builtins.function?(:inverse)
    assert RLSL::Prism::Builtins.function?(:transpose)
    assert RLSL::Prism::Builtins.function?(:determinant)
  end

  test "function? returns true for texture functions" do
    assert RLSL::Prism::Builtins.function?(:texture2D)
    assert RLSL::Prism::Builtins.function?(:texture)
    assert RLSL::Prism::Builtins.function?(:textureLod)
  end

  test "function_signature for mat4 constructor" do
    sig = RLSL::Prism::Builtins.function_signature(:mat4)
    assert_equal :mat4, sig[:returns]
    assert sig[:variadic]
    assert_equal 1, sig[:min_args]
  end

  test "function_signature for texture2D" do
    sig = RLSL::Prism::Builtins.function_signature(:texture2D)
    assert_equal :vec4, sig[:returns]
    assert_equal %i[sampler2D vec2], sig[:args]
  end

  test "function_signature for inverse" do
    sig = RLSL::Prism::Builtins.function_signature(:inverse)
    assert_equal :same, sig[:returns]
  end

  test "function_signature for determinant" do
    sig = RLSL::Prism::Builtins.function_signature(:determinant)
    assert_equal :float, sig[:returns]
  end

  test "matrix_type? identifies matrices" do
    assert RLSL::Prism::Builtins.matrix_type?(:mat2)
    assert RLSL::Prism::Builtins.matrix_type?(:mat3)
    assert RLSL::Prism::Builtins.matrix_type?(:mat4)
    assert_false RLSL::Prism::Builtins.matrix_type?(:float)
    assert_false RLSL::Prism::Builtins.matrix_type?(:vec4)
  end

  test "matrix_vector_result returns correct vector type" do
    assert_equal :vec2, RLSL::Prism::Builtins.matrix_vector_result(:mat2)
    assert_equal :vec3, RLSL::Prism::Builtins.matrix_vector_result(:mat3)
    assert_equal :vec4, RLSL::Prism::Builtins.matrix_vector_result(:mat4)
  end

  test "binary_op_result_type for matrix-vector multiplication" do
    assert_equal :vec4, RLSL::Prism::Builtins.binary_op_result_type("*", :mat4, :vec4)
    assert_equal :vec3, RLSL::Prism::Builtins.binary_op_result_type("*", :mat3, :vec3)
    assert_equal :vec2, RLSL::Prism::Builtins.binary_op_result_type("*", :mat2, :vec2)
  end

  test "binary_op_result_type for vector-matrix multiplication" do
    assert_equal :vec4, RLSL::Prism::Builtins.binary_op_result_type("*", :vec4, :mat4)
  end

  test "binary_op_result_type for matrix-matrix multiplication" do
    assert_equal :mat4, RLSL::Prism::Builtins.binary_op_result_type("*", :mat4, :mat4)
    assert_equal :mat3, RLSL::Prism::Builtins.binary_op_result_type("*", :mat3, :mat3)
  end

  test "binary_op_result_type for matrix-scalar multiplication" do
    assert_equal :mat4, RLSL::Prism::Builtins.binary_op_result_type("*", :mat4, :float)
    assert_equal :mat4, RLSL::Prism::Builtins.binary_op_result_type("*", :float, :mat4)
  end
end

class PrismTypeInferenceTest < Test::Unit::TestCase
  test "register and lookup variables" do
    inference = RLSL::Prism::TypeInference.new
    inference.register(:x, :float)
    assert_equal :float, inference.lookup(:x)
  end

  test "uniforms are registered on initialization" do
    inference = RLSL::Prism::TypeInference.new(time: :float, color: :vec3)
    assert_equal :float, inference.lookup(:time)
    assert_equal :vec3, inference.lookup(:color)
  end

  test "infer literal type" do
    inference = RLSL::Prism::TypeInference.new
    node = RLSL::Prism::IR::Literal.new(1.5)
    inference.infer(node)
    assert_equal :float, node.type
  end

  test "infer var_decl type from initializer" do
    inference = RLSL::Prism::TypeInference.new
    init = RLSL::Prism::IR::FuncCall.new(:vec3, [], nil, :vec3)
    node = RLSL::Prism::IR::VarDecl.new(:color, init)
    inference.infer(node)
    assert_equal :vec3, node.type
  end

  test "infer binary op type" do
    inference = RLSL::Prism::TypeInference.new
    left = RLSL::Prism::IR::Literal.new(1.0, :float)
    right = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right)
    inference.infer(node)
    assert_equal :float, node.type
  end

  test "infer comparison op type is bool" do
    inference = RLSL::Prism::TypeInference.new
    left = RLSL::Prism::IR::Literal.new(1.0, :float)
    right = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::BinaryOp.new("<", left, right)
    inference.infer(node)
    assert_equal :bool, node.type
  end

  test "infer func call return type" do
    inference = RLSL::Prism::TypeInference.new
    args = [RLSL::Prism::IR::Literal.new(0.5, :float)]
    node = RLSL::Prism::IR::FuncCall.new(:sin, args)
    inference.infer(node)
    assert_equal :float, node.type
  end

  test "infer field access from vector" do
    inference = RLSL::Prism::TypeInference.new
    receiver = RLSL::Prism::IR::VarRef.new(:v, :vec3)
    node = RLSL::Prism::IR::FieldAccess.new(receiver, "x")
    inference.infer(node)
    assert_equal :float, node.type
  end

  test "infer swizzle type" do
    inference = RLSL::Prism::TypeInference.new
    receiver = RLSL::Prism::IR::VarRef.new(:v, :vec3)
    node = RLSL::Prism::IR::Swizzle.new(receiver, "xy")
    inference.infer(node)
    assert_equal :vec2, node.type
  end

  test "infer block with multiple statements" do
    inference = RLSL::Prism::TypeInference.new
    stmt1 = RLSL::Prism::IR::VarDecl.new(:x, RLSL::Prism::IR::Literal.new(1.0), :float)
    stmt2 = RLSL::Prism::IR::Return.new(RLSL::Prism::IR::VarRef.new(:x))
    block = RLSL::Prism::IR::Block.new([stmt1, stmt2])
    inference.infer(block)
    assert_equal :float, inference.lookup(:x)
  end

  test "infer if statement branches" do
    inference = RLSL::Prism::TypeInference.new
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    then_branch = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Literal.new(1.0)])
    node = RLSL::Prism::IR::IfStatement.new(condition, then_branch, nil)
    inference.infer(node) # Should not raise
  end

  test "infer assignment updates variable type" do
    inference = RLSL::Prism::TypeInference.new
    inference.register(:x, :float)
    target = RLSL::Prism::IR::VarRef.new(:x)
    value = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::Assignment.new(target, value)
    inference.infer(node) # Should not raise
  end

  test "infer unary op" do
    inference = RLSL::Prism::TypeInference.new
    operand = RLSL::Prism::IR::BoolLiteral.new(true)
    node = RLSL::Prism::IR::UnaryOp.new("!", operand)
    inference.infer(node)
    assert_equal :bool, node.type
  end

  test "infer for loop body" do
    inference = RLSL::Prism::TypeInference.new
    body = RLSL::Prism::IR::Block.new([RLSL::Prism::IR::Literal.new(1.0)])
    node = RLSL::Prism::IR::ForLoop.new(:i,
      RLSL::Prism::IR::Literal.new(0, :int),
      RLSL::Prism::IR::Literal.new(10, :int),
      body
    )
    inference.infer(node) # Should not raise
  end

  test "infer parenthesized expression" do
    inference = RLSL::Prism::TypeInference.new
    inner = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Parenthesized.new(inner)
    inference.infer(node)
    assert_equal :float, node.type
  end
end

class PrismEmittersTest < Test::Unit::TestCase
  test "CEmitter emits float literals with f suffix" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    node = RLSL::Prism::IR::Literal.new(1.5, :float)
    assert_equal "1.5f", emitter.emit(node)
  end

  test "CEmitter emits vec3_new for vec3 constructor" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec3, args)
    assert_equal "vec3_new(1.0f, 0.0f, 0.0f)", emitter.emit(node)
  end

  test "MSLEmitter emits float3 for vec3 constructor" do
    emitter = RLSL::Prism::Emitters::MSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec3, args)
    assert_equal "float3(1.0, 0.0, 0.0)", emitter.emit(node)
  end

  test "WGSLEmitter emits vec3<f32> for vec3 constructor" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec3, args)
    assert_equal "vec3<f32>(1.0, 0.0, 0.0)", emitter.emit(node)
  end

  test "GLSLEmitter emits vec3 for vec3 constructor" do
    emitter = RLSL::Prism::Emitters::GLSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec3, args)
    assert_equal "vec3(1.0, 0.0, 0.0)", emitter.emit(node)
  end

  test "CEmitter emits boolean literals as 0/1" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    assert_equal "1", emitter.emit(RLSL::Prism::IR::BoolLiteral.new(true))
    assert_equal "0", emitter.emit(RLSL::Prism::IR::BoolLiteral.new(false))
  end

  test "CEmitter emits math functions" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    arg = RLSL::Prism::IR::Literal.new(0.5, :float)

    sin_call = RLSL::Prism::IR::FuncCall.new(:sin, [arg])
    assert_equal "sinf(0.5f)", emitter.emit(sin_call)

    cos_call = RLSL::Prism::IR::FuncCall.new(:cos, [arg])
    assert_equal "cosf(0.5f)", emitter.emit(cos_call)

    sqrt_call = RLSL::Prism::IR::FuncCall.new(:sqrt, [arg])
    assert_equal "sqrtf(0.5f)", emitter.emit(sqrt_call)
  end

  test "CEmitter emits vec2 constructor" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec2, args)
    assert_equal "vec2_new(1.0f, 2.0f)", emitter.emit(node)
  end

  test "CEmitter emits vec4 constructor" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(1.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec4, args)
    assert_equal "vec4_new(1.0f, 0.0f, 0.0f, 1.0f)", emitter.emit(node)
  end

  test "MSLEmitter emits math functions unchanged" do
    emitter = RLSL::Prism::Emitters::MSLEmitter.new
    arg = RLSL::Prism::IR::Literal.new(0.5, :float)
    sin_call = RLSL::Prism::IR::FuncCall.new(:sin, [arg])
    assert_equal "sin(0.5)", emitter.emit(sin_call)
  end

  test "MSLEmitter emits float2 for vec2" do
    emitter = RLSL::Prism::Emitters::MSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec2, args)
    assert_equal "float2(1.0, 2.0)", emitter.emit(node)
  end

  test "MSLEmitter emits float4 for vec4" do
    emitter = RLSL::Prism::Emitters::MSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(1.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec4, args)
    assert_equal "float4(1.0, 0.0, 0.0, 1.0)", emitter.emit(node)
  end

  test "WGSLEmitter emits vec2<f32> for vec2" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec2, args)
    assert_equal "vec2<f32>(1.0, 2.0)", emitter.emit(node)
  end

  test "WGSLEmitter emits vec4<f32> for vec4" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(1.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec4, args)
    assert_equal "vec4<f32>(1.0, 0.0, 0.0, 1.0)", emitter.emit(node)
  end

  test "GLSLEmitter emits vec2 for vec2" do
    emitter = RLSL::Prism::Emitters::GLSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec2, args)
    assert_equal "vec2(1.0, 2.0)", emitter.emit(node)
  end

  test "GLSLEmitter emits vec4 for vec4" do
    emitter = RLSL::Prism::Emitters::GLSLEmitter.new
    args = [
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(0.0, :float),
      RLSL::Prism::IR::Literal.new(1.0, :float)
    ]
    node = RLSL::Prism::IR::FuncCall.new(:vec4, args)
    assert_equal "vec4(1.0, 0.0, 0.0, 1.0)", emitter.emit(node)
  end

  test "emitters emit unary operators" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    node = RLSL::Prism::IR::UnaryOp.new("-", RLSL::Prism::IR::Literal.new(1.0, :float))
    assert_equal "-1.0f", emitter.emit(node)
  end

  test "emitters emit parenthesized expressions" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    inner = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Parenthesized.new(inner)
    assert_equal "(1.0f)", emitter.emit(node)
  end

  test "emitters emit assignment" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    target = RLSL::Prism::IR::VarRef.new(:x)
    value = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::Assignment.new(target, value)
    assert_equal "x = 2.0f", emitter.emit(node)
  end

  test "emitters emit for loop" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    body = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::VarDecl.new(:y, RLSL::Prism::IR::VarRef.new(:i), :int)
    ])
    node = RLSL::Prism::IR::ForLoop.new(
      :i,
      RLSL::Prism::IR::Literal.new(0, :int),
      RLSL::Prism::IR::Literal.new(10, :int),
      body
    )
    code = emitter.emit(node)
    assert code.include?("for (int i = 0.0f; i < 10.0f; i++)")
  end

  test "emitters emit if statement with else" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    then_branch = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(1.0, :float))
    ])
    else_branch = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(0.0, :float))
    ])
    node = RLSL::Prism::IR::IfStatement.new(condition, then_branch, else_branch)
    code = emitter.emit(node)
    assert code.include?("if (1)")
    assert code.include?("else")
  end

  test "emitters emit swizzle" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    receiver = RLSL::Prism::IR::VarRef.new(:v)
    node = RLSL::Prism::IR::Swizzle.new(receiver, "xyz", :vec3)
    assert_equal "v.xyz", emitter.emit(node)
  end

  test "emitters emit field access" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    receiver = RLSL::Prism::IR::VarRef.new(:v)
    node = RLSL::Prism::IR::FieldAccess.new(receiver, "x", :float)
    assert_equal "v.x", emitter.emit(node)
  end

  test "emitters emit return without expression" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    node = RLSL::Prism::IR::Return.new(nil)
    assert_equal "return", emitter.emit(node)
  end

  test "CEmitter handles vector operations" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    left = RLSL::Prism::IR::VarRef.new(:a, :vec3)
    right = RLSL::Prism::IR::VarRef.new(:b, :vec3)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right, :vec3)
    left.instance_variable_set(:@type, :vec3)
    code = emitter.emit(node)
    assert code.include?("vec3_add")
  end

  test "WGSLEmitter emits let declarations" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    node = RLSL::Prism::IR::VarDecl.new(:x, RLSL::Prism::IR::Literal.new(1.0, :float), :float)
    code = emitter.emit(node)
    assert code.include?("let x")
    assert code.include?("f32")
  end

  test "raises on unknown node type" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    assert_raise(RuntimeError) do
      emitter.emit("not a node")
    end
  end

  test "WGSLEmitter emits for loop with WGSL syntax" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    body = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::VarDecl.new(:y, RLSL::Prism::IR::VarRef.new(:i), :int)
    ])
    node = RLSL::Prism::IR::ForLoop.new(
      :i,
      RLSL::Prism::IR::Literal.new(0, :int),
      RLSL::Prism::IR::Literal.new(10, :int),
      body
    )
    code = emitter.emit(node)
    assert code.include?("for (var i: i32 = 0.0")
  end

  test "WGSLEmitter emits binary operators" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    left = RLSL::Prism::IR::Literal.new(1.0, :float)
    right = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right)
    assert_equal "1.0 + 2.0", emitter.emit(node)
  end

  test "WGSLEmitter emits standard functions" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    arg = RLSL::Prism::IR::Literal.new(0.5, :float)
    node = RLSL::Prism::IR::FuncCall.new(:sin, [arg])
    assert_equal "sin(0.5)", emitter.emit(node)
  end

  test "GLSLEmitter emits binary operators" do
    emitter = RLSL::Prism::Emitters::GLSLEmitter.new
    left = RLSL::Prism::IR::Literal.new(1.0, :float)
    right = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right)
    assert_equal "1.0 + 2.0", emitter.emit(node)
  end

  test "GLSLEmitter emits standard functions" do
    emitter = RLSL::Prism::Emitters::GLSLEmitter.new
    arg = RLSL::Prism::IR::Literal.new(0.5, :float)
    node = RLSL::Prism::IR::FuncCall.new(:sin, [arg])
    assert_equal "sin(0.5)", emitter.emit(node)
  end

  test "GLSLEmitter type_name defaults to float" do
    emitter = RLSL::Prism::Emitters::GLSLEmitter.new
    node = RLSL::Prism::IR::VarDecl.new(:x, RLSL::Prism::IR::Literal.new(1.0, :float), nil)
    code = emitter.emit(node)
    assert code.include?("float x")
  end

  test "WGSLEmitter type_name defaults to f32" do
    emitter = RLSL::Prism::Emitters::WGSLEmitter.new
    node = RLSL::Prism::IR::VarDecl.new(:x, RLSL::Prism::IR::Literal.new(1.0, :float), nil)
    code = emitter.emit(node)
    assert code.include?("f32")
  end

  test "CEmitter type_name defaults to float" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    node = RLSL::Prism::IR::VarDecl.new(:x, RLSL::Prism::IR::Literal.new(1.0, :float), nil)
    code = emitter.emit(node)
    assert code.include?("float x")
  end

  test "MSLEmitter type_name defaults to float" do
    emitter = RLSL::Prism::Emitters::MSLEmitter.new
    node = RLSL::Prism::IR::VarDecl.new(:x, RLSL::Prism::IR::Literal.new(1.0, :float), nil)
    code = emitter.emit(node)
    assert code.include?("float x")
  end

  test "MSLEmitter emits binary operators" do
    emitter = RLSL::Prism::Emitters::MSLEmitter.new
    left = RLSL::Prism::IR::Literal.new(1.0, :float)
    right = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right)
    assert_equal "1.0 + 2.0", emitter.emit(node)
  end

  test "base emitter emits if without else" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    then_branch = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(1.0, :float))
    ])
    node = RLSL::Prism::IR::IfStatement.new(condition, then_branch, nil)
    code = emitter.emit(node)
    assert code.include?("if (1)")
    assert_false code.include?("else")
  end

  test "base emitter emits bool literal directly" do
    emitter = RLSL::Prism::Emitters::GLSLEmitter.new
    node = RLSL::Prism::IR::BoolLiteral.new(true)
    assert_equal "true", emitter.emit(node)
  end

  test "base emitter emits function call with receiver" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    receiver = RLSL::Prism::IR::VarRef.new(:obj)
    args = [RLSL::Prism::IR::Literal.new(1.0, :float)]
    node = RLSL::Prism::IR::FuncCall.new(:custom_method, args, receiver)
    code = emitter.emit(node)
    assert code.include?("custom_method(obj, 1.0f)")
  end

  test "emitters emit while loop" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    condition = RLSL::Prism::IR::BinaryOp.new("<",
      RLSL::Prism::IR::VarRef.new(:x),
      RLSL::Prism::IR::Literal.new(10.0, :float))
    body = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Assignment.new(
        RLSL::Prism::IR::VarRef.new(:x),
        RLSL::Prism::IR::BinaryOp.new("+",
          RLSL::Prism::IR::VarRef.new(:x),
          RLSL::Prism::IR::Literal.new(1.0, :float)))
    ])
    node = RLSL::Prism::IR::WhileLoop.new(condition, body)
    code = emitter.emit(node)
    assert code.include?("while (x < 10.0f)")
    assert code.include?("x = x + 1.0f")
  end

  test "emitters emit break statement" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    node = RLSL::Prism::IR::Break.new
    assert_equal "break", emitter.emit(node)
  end

  test "emitters emit PI constant" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    node = RLSL::Prism::IR::Constant.new(:PI, :float)
    code = emitter.emit(node)
    assert code.include?("3.14159")
  end

  test "emitters emit TAU constant" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    node = RLSL::Prism::IR::Constant.new(:TAU, :float)
    code = emitter.emit(node)
    assert code.include?("6.28318")
  end

  test "emitters emit elsif as else if" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    condition1 = RLSL::Prism::IR::BinaryOp.new(">",
      RLSL::Prism::IR::VarRef.new(:x),
      RLSL::Prism::IR::Literal.new(0.0, :float))
    condition2 = RLSL::Prism::IR::BinaryOp.new("<",
      RLSL::Prism::IR::VarRef.new(:x),
      RLSL::Prism::IR::Literal.new(0.0, :float))
    then_branch = RLSL::Prism::IR::Block.new([
      RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(1.0, :float))
    ])
    elsif_branch = RLSL::Prism::IR::IfStatement.new(
      condition2,
      RLSL::Prism::IR::Block.new([
        RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(-1.0, :float))
      ]),
      RLSL::Prism::IR::Block.new([
        RLSL::Prism::IR::Return.new(RLSL::Prism::IR::Literal.new(0.0, :float))
      ])
    )
    node = RLSL::Prism::IR::IfStatement.new(condition1, then_branch, elsif_branch)
    code = emitter.emit(node)
    assert code.include?("if (x > 0.0f)")
    assert code.include?("else if (x < 0.0f)")
    assert code.include?("else {")
  end

  test "base emitter handles operator precedence" do
    emitter = RLSL::Prism::Emitters::GLSLEmitter.new
    inner_add = RLSL::Prism::IR::BinaryOp.new("+",
      RLSL::Prism::IR::Literal.new(1.0, :float),
      RLSL::Prism::IR::Literal.new(2.0, :float))
    outer_mul = RLSL::Prism::IR::BinaryOp.new("*",
      inner_add,
      RLSL::Prism::IR::Literal.new(3.0, :float))
    code = emitter.emit(outer_mul)
    assert code.include?("(1.0 + 2.0) * 3.0")
  end

  test "CEmitter emits generic function call via super" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    args = [RLSL::Prism::IR::Literal.new(1.0, :float)]
    node = RLSL::Prism::IR::FuncCall.new(:unknown_func, args)
    code = emitter.emit(node)
    assert_equal "unknown_func(1.0f)", code
  end

  test "CEmitter scalar binary op uses super" do
    emitter = RLSL::Prism::Emitters::CEmitter.new
    left = RLSL::Prism::IR::Literal.new(1.0, :float)
    right = RLSL::Prism::IR::Literal.new(2.0, :float)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right)
    code = emitter.emit(node)
    assert_equal "1.0f + 2.0f", code
  end
end

class ShaderBuilderRubyModeTest < Test::Unit::TestCase
  test "detects ruby mode based on block arity" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.fragment { "C code" }
    assert_false builder.ruby_mode?

    builder2 = RLSL::ShaderBuilder.new(:test2)
    builder2.fragment { |frag_coord, resolution, u| vec3(1.0, 0.0, 0.0) }
    assert_true builder2.ruby_mode?
  end

  test "uniforms can be defined with block" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.uniforms do
      float :time
      vec3 :color
    end
    uniforms = builder.uniforms
    assert_equal :float, uniforms[:time]
    assert_equal :vec3, uniforms[:color]
  end

  test "uniforms returns hash without block" do
    builder = RLSL::ShaderBuilder.new(:test)
    assert_equal({}, builder.uniforms)
  end

  test "helpers can be defined" do
    builder = RLSL::ShaderBuilder.new(:test)
    builder.helpers(:c) { "float helper() { return 1.0; }" }
    builder.fragment { "return helper();" }
    # Helpers block is stored
    assert_not_nil builder.instance_variable_get(:@helpers_block)
  end

  test "transpile_fragment returns empty string without block" do
    builder = RLSL::ShaderBuilder.new(:test)
    assert_equal "", builder.transpile_fragment(:c)
  end

  test "name accessor returns shader name" do
    builder = RLSL::ShaderBuilder.new(:my_shader)
    assert_equal "my_shader", builder.name
  end
end

class PrismSourceExtractorTest < Test::Unit::TestCase
  def setup
    @extractor = RLSL::Prism::SourceExtractor.new
  end

  test "extract_from_string returns source unchanged" do
    source = "x = 1.0"
    assert_equal source, @extractor.extract_from_string(source)
  end

  test "raises error for block without source location" do
    block = proc { }
    # Mock source_location to return nil
    block.define_singleton_method(:source_location) { [nil, nil] }
    assert_raise(RLSL::Prism::SourceExtractor::SourceNotAvailable) do
      @extractor.extract(block)
    end
  end

  test "extract from do..end block" do
    block = proc do |x|
      y = x + 1.0
      y
    end
    source = @extractor.extract(block)
    assert source.include?("y = x + 1.0")
  end

  test "extract from brace block" do
    block = proc { |x| x + 1.0 }
    source = @extractor.extract(block)
    assert source.include?("x + 1.0")
  end

  test "extract block with parameters" do
    block = proc { |a, b, c| a + b + c }
    source = @extractor.extract(block)
    assert source.include?("|a, b, c|")
  end

  test "extract multiline block" do
    block = proc do
      x = 1.0
      y = 2.0
      z = x + y
      z
    end
    source = @extractor.extract(block)
    assert source.include?("x = 1.0")
    assert source.include?("y = 2.0")
    assert source.include?("z = x + y")
  end

  test "extract handles strings in code" do
    block = proc do
      s = "hello { world } do end"
      s
    end
    source = @extractor.extract(block)
    assert source.include?("hello { world } do end")
  end

  test "extract handles comments in code" do
    block = proc do
      x = 1.0 # This is { a comment with } braces
      x
    end
    source = @extractor.extract(block)
    assert source.include?("x = 1.0")
  end
end

class PrismASTVisitorTest < Test::Unit::TestCase
  def setup
    @visitor = RLSL::Prism::ASTVisitor.new(uniforms: { time: :float })
  end

  test "parse integer literal promotes to float" do
    ir = @visitor.parse("x = 1\nreturn x")
    stmt = ir.statements.first
    assert_equal :float, stmt.initializer.type
  end

  test "parse true literal" do
    ir = @visitor.parse("x = true\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::BoolLiteral, stmt.initializer
    assert_equal true, stmt.initializer.value
  end

  test "parse false literal" do
    ir = @visitor.parse("x = false\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::BoolLiteral, stmt.initializer
    assert_equal false, stmt.initializer.value
  end

  test "parse reassignment" do
    ir = @visitor.parse("x = 1.0\nx = 2.0\nreturn x")
    assert_kind_of RLSL::Prism::IR::VarDecl, ir.statements[0]
    assert_kind_of RLSL::Prism::IR::Assignment, ir.statements[1]
  end

  test "parse unary minus" do
    ir = @visitor.parse("x = -1.0\nreturn x")
    stmt = ir.statements.first
    # Prism parses -1.0 as a negative float literal directly
    assert_kind_of RLSL::Prism::IR::Literal, stmt.initializer
  end

  test "parse and operator" do
    ir = @visitor.parse("x = true && false\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::BinaryOp, stmt.initializer
    assert_equal "&&", stmt.initializer.operator
  end

  test "parse or operator" do
    ir = @visitor.parse("x = true || false\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::BinaryOp, stmt.initializer
    assert_equal "||", stmt.initializer.operator
  end

  test "parse comparison operators" do
    ir = @visitor.parse("x = 1.0 < 2.0\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::BinaryOp, stmt.initializer
    assert_equal "<", stmt.initializer.operator
  end

  test "parse parenthesized expression" do
    ir = @visitor.parse("x = (1.0 + 2.0)\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::Parenthesized, stmt.initializer
  end

  test "parse swizzle xy" do
    ir = @visitor.parse("v = vec2(1.0, 2.0)\nx = v.xy\nreturn x")
    stmt = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::Swizzle, stmt.initializer
    assert_equal "xy", stmt.initializer.components
  end

  test "parse if statement" do
    source = <<~RUBY
      if x > 0
        y = 1.0
      else
        y = 2.0
      end
      return y
    RUBY
    ir = @visitor.parse(source)
    assert_kind_of RLSL::Prism::IR::IfStatement, ir.statements.first
  end

  test "parse for loop" do
    source = <<~RUBY
      for i in 0..10
        x = i
      end
      return x
    RUBY
    ir = @visitor.parse(source)
    assert_kind_of RLSL::Prism::IR::ForLoop, ir.statements.first
  end

  test "parse explicit return" do
    ir = @visitor.parse("return 1.0")
    assert_kind_of RLSL::Prism::IR::Return, ir.statements.first
  end

  test "parse empty return" do
    ir = @visitor.parse("return")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::Return, stmt
    assert_nil stmt.expression
  end

  test "raises on parse error" do
    assert_raise(RuntimeError) do
      @visitor.parse("def invalid syntax(")
    end
  end

  test "parse unless statement converts to negated if" do
    source = <<~RUBY
      unless x > 0
        y = 1.0
      end
      return y
    RUBY
    ir = @visitor.parse(source)
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::IfStatement, stmt
    # The condition should be negated (wrapped in UnaryOp)
    assert_kind_of RLSL::Prism::IR::UnaryOp, stmt.condition
  end

  test "parse elsif as nested if" do
    source = <<~RUBY
      if x > 0
        y = 1.0
      elsif x < 0
        y = -1.0
      else
        y = 0.0
      end
      return y
    RUBY
    ir = @visitor.parse(source)
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::IfStatement, stmt
    # The else_branch should be another IfStatement (for elsif)
    assert_kind_of RLSL::Prism::IR::IfStatement, stmt.else_branch
  end

  test "parse negation operator" do
    # Negation on a variable uses unary minus
    ir = @visitor.parse("a = 1.0\nx = -a\nreturn x")
    stmt = ir.statements[1]
    # Check that the initializer involves the negated variable
    assert_not_nil stmt.initializer
  end

  test "parse method call on receiver" do
    ir = @visitor.parse("x = sin(0.5)\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_nil stmt.initializer.receiver
  end

  test "parse uniform field access" do
    ir = @visitor.parse("x = u.time\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FieldAccess, stmt.initializer
    assert_equal "time", stmt.initializer.field
  end

  test "parse rational literal as float" do
    ir = @visitor.parse("x = 1/2r\nreturn x")
    # Rational handling may vary but should convert to float
    stmt = ir.statements.first
    assert_not_nil stmt.initializer
  end

  test "parse block parameters" do
    # Block parameters are tracked for type inference
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    # Simulate block-like structure
    ir = visitor.parse("frag_coord = vec2(0.0, 0.0)\nreturn frag_coord")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::VarDecl, stmt
  end

  test "parse local variable reference after assignment" do
    ir = @visitor.parse("y = 1.0\nx = y\nreturn x")
    stmt = ir.statements[1]
    # y is a VarRef after being assigned
    assert_kind_of RLSL::Prism::IR::VarRef, stmt.initializer
    assert_equal :y, stmt.initializer.name
  end

  test "parse undefined method as function call" do
    ir = @visitor.parse("x = some_func()\nreturn x")
    stmt = ir.statements.first
    # Undefined identifiers are parsed as function calls
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :some_func, stmt.initializer.name
  end

  test "parse while loop" do
    source = <<~RUBY
      x = 0.0
      while x < 10.0
        x = x + 1.0
      end
      return x
    RUBY
    ir = @visitor.parse(source)
    assert_kind_of RLSL::Prism::IR::WhileLoop, ir.statements[1]
  end

  test "parse break statement" do
    source = <<~RUBY
      x = 0.0
      while x < 10.0
        break
      end
      return x
    RUBY
    ir = @visitor.parse(source)
    while_node = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::WhileLoop, while_node
    assert_kind_of RLSL::Prism::IR::Break, while_node.body.statements.first
  end

  test "parse PI constant" do
    ir = @visitor.parse("x = PI\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::Constant, stmt.initializer
    assert_equal :PI, stmt.initializer.name
  end

  test "parse TAU constant" do
    ir = @visitor.parse("x = TAU\nreturn x")
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::Constant, stmt.initializer
    assert_equal :TAU, stmt.initializer.name
  end
end

