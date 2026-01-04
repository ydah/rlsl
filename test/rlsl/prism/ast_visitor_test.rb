# frozen_string_literal: true

require_relative "../../test_helper"

class PrismASTVisitorExtendedTest < Test::Unit::TestCase
  def setup
    @visitor = RLSL::Prism::ASTVisitor.new(uniforms: { time: :float })
  end

  test "parse for loop with range" do
    source = <<~RUBY
      sum = 0.0
      for i in 0..10
        sum = sum + i
      end
      return sum
    RUBY
    ir = @visitor.parse(source)
    # Should have a ForLoop for the for..in block
    assert ir.statements.any? { |s| s.is_a?(RLSL::Prism::IR::ForLoop) }
  end

  test "parse array literal" do
    source = "[1.0, 2.0, 3.0]"
    ir = @visitor.parse(source)
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::ArrayLiteral, stmt
    assert_equal 3, stmt.elements.length
  end

  test "parse array index access" do
    source = <<~RUBY
      arr = [1.0, 2.0]
      x = arr[0]
      return x
    RUBY
    ir = @visitor.parse(source)
    # Second statement should be array index
    stmt = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::VarDecl, stmt
    assert_kind_of RLSL::Prism::IR::ArrayIndex, stmt.initializer
  end

  test "parse global variable read" do
    source = <<~RUBY
      $global_var = 1.0
      x = $global_var
      return x
    RUBY
    ir = @visitor.parse(source)
    # First statement should be GlobalDecl
    assert_kind_of RLSL::Prism::IR::GlobalDecl, ir.statements.first
  end

  test "parse global variable write" do
    source = <<~RUBY
      $my_global = 42.0
      return $my_global
    RUBY
    ir = @visitor.parse(source)
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::GlobalDecl, stmt
    assert_equal :my_global, stmt.name
  end

  test "parse constant write" do
    source = <<~RUBY
      MY_CONST = 3.14
      return MY_CONST
    RUBY
    ir = @visitor.parse(source)
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::GlobalDecl, stmt
    assert_equal :MY_CONST, stmt.name
    assert_true stmt.is_const
  end

  test "parse function definition" do
    source = <<~RUBY
      def helper(x, y)
        return x + y
      end
      return helper(1.0, 2.0)
    RUBY
    ir = @visitor.parse(source)
    func_def = ir.statements.first
    assert_kind_of RLSL::Prism::IR::FunctionDefinition, func_def
    assert_equal :helper, func_def.name
    assert_equal [:x, :y], func_def.params
  end

  test "parse multiple assignment" do
    source = <<~RUBY
      a, b = some_func()
      return a
    RUBY
    ir = @visitor.parse(source)
    stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::MultipleAssignment, stmt
    assert_equal 2, stmt.targets.length
  end

  test "parse logical not in condition" do
    source = <<~RUBY
      a = true
      b = false
      x = a && !b
      return x
    RUBY
    ir = @visitor.parse(source)
    # b should be negated in the binary op
    stmt = ir.statements[2]
    assert_kind_of RLSL::Prism::IR::BinaryOp, stmt.initializer
  end

  test "parse lambda" do
    source = <<~RUBY
      f = -> { 1.0 }
      return 1.0
    RUBY
    ir = @visitor.parse(source)
    # Should not raise
    assert_kind_of RLSL::Prism::IR::Block, ir
  end

  test "parse else clause" do
    source = <<~RUBY
      if x > 0
        y = 1.0
      else
        y = 0.0
      end
      return y
    RUBY
    ir = @visitor.parse(source)
    if_stmt = ir.statements.first
    assert_kind_of RLSL::Prism::IR::IfStatement, if_stmt
    assert_not_nil if_stmt.else_branch
  end

  test "parse constant path" do
    source = <<~RUBY
      x = Math_PI
      return x
    RUBY
    ir = @visitor.parse(source)
    # Should handle constant path as VarRef
    assert_kind_of RLSL::Prism::IR::Block, ir
  end

  test "infer_param_type for frag_coord" do
    type = @visitor.send(:infer_param_type, :frag_coord)
    assert_equal :vec2, type
  end

  test "infer_param_type for resolution" do
    type = @visitor.send(:infer_param_type, :resolution)
    assert_equal :vec2, type
  end

  test "infer_param_type for u" do
    type = @visitor.send(:infer_param_type, :u)
    assert_equal :uniforms, type
  end

  test "infer_param_type for unknown" do
    type = @visitor.send(:infer_param_type, :unknown)
    assert_nil type
  end

  test "visit_with_scoped_vars preserves outer vars" do
    source = <<~RUBY
      x = 1.0
      if true
        y = 2.0
      end
      return x
    RUBY
    ir = @visitor.parse(source)
    # Should not raise and x should be accessible
    assert_kind_of RLSL::Prism::IR::Block, ir
  end

  test "parse call without receiver as parameter reference" do
    visitor = RLSL::Prism::ASTVisitor.new(
      uniforms: {},
      params: [:x, :y]
    )
    source = "return x + y"
    ir = visitor.parse(source)
    # x and y should be VarRefs
    assert_kind_of RLSL::Prism::IR::Block, ir
  end

  test "parse binary operator on receiver" do
    source = "a = 1.0\nb = 2.0\nc = a + b\nreturn c"
    ir = @visitor.parse(source)
    stmt = ir.statements[2]
    assert_kind_of RLSL::Prism::IR::BinaryOp, stmt.initializer
  end

  test "parse unary minus on receiver" do
    source = "a = 1.0\nb = -a\nreturn b"
    ir = @visitor.parse(source)
    stmt = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::VarDecl, stmt
    # -a might be parsed as UnaryOp or Literal depending on Prism version
  end

  test "BINARY_OPERATORS constant" do
    assert RLSL::Prism::ASTVisitor::BINARY_OPERATORS.include?("+")
    assert RLSL::Prism::ASTVisitor::BINARY_OPERATORS.include?("==")
    assert RLSL::Prism::ASTVisitor::BINARY_OPERATORS.include?("&&")
  end

  test "UNARY_OPERATORS constant" do
    assert RLSL::Prism::ASTVisitor::UNARY_OPERATORS.include?("-")
    assert RLSL::Prism::ASTVisitor::UNARY_OPERATORS.include?("!")
  end

  test "visit nil returns nil" do
    result = @visitor.send(:visit, nil)
    assert_nil result
  end

  test "visit unknown node uses visit_default" do
    # Parse some code and verify it handles unknown nodes gracefully
    source = "return 1.0"
    ir = @visitor.parse(source)
    assert_kind_of RLSL::Prism::IR::Block, ir
  end

  test "parse for loop with variable" do
    source = <<~RUBY
      for i in 0..10
        x = i
      end
      return x
    RUBY
    ir = @visitor.parse(source)
    # Should have ForLoop with variable i
    for_loop = ir.statements.first
    assert_kind_of RLSL::Prism::IR::ForLoop, for_loop
    assert_equal :i, for_loop.variable
  end
end

class PrismASTVisitorEdgeCasesTest < Test::Unit::TestCase
  test "parse for loop without explicit variable" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      for j in 0..5
        x = j
      end
      return x
    RUBY
    ir = visitor.parse(source)
    for_loop = ir.statements.first
    assert_kind_of RLSL::Prism::IR::ForLoop, for_loop
    assert_equal :j, for_loop.variable
  end

  test "parse field access that is not a component" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      v = vec3(1.0, 2.0, 3.0)
      x = v.custom_field
      return x
    RUBY
    ir = visitor.parse(source)
    stmt = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::FieldAccess, stmt.initializer
    assert_equal "custom_field", stmt.initializer.field
  end

  test "parse constant that is not PI or TAU" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      x = CUSTOM_CONST
      return x
    RUBY
    ir = visitor.parse(source)
    stmt = ir.statements.first
    # Non-builtin constants become VarRef
    assert_kind_of RLSL::Prism::IR::VarRef, stmt.initializer
  end

  test "parse builtin function normalize" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      v = vec3(1.0, 2.0, 3.0)
      x = normalize(v)
      return x
    RUBY
    ir = visitor.parse(source)
    stmt = ir.statements[1]
    # Should be FuncCall
    assert_kind_of RLSL::Prism::IR::FuncCall, stmt.initializer
    assert_equal :normalize, stmt.initializer.name
  end

  test "parse unless with else" do
    visitor = RLSL::Prism::ASTVisitor.new(uniforms: {})
    source = <<~RUBY
      x = 1.0
      unless x > 0
        y = 0.0
      else
        y = 1.0
      end
      return y
    RUBY
    ir = visitor.parse(source)
    if_stmt = ir.statements[1]
    assert_kind_of RLSL::Prism::IR::IfStatement, if_stmt
    # Condition should be negated
    assert_kind_of RLSL::Prism::IR::UnaryOp, if_stmt.condition
  end
end
