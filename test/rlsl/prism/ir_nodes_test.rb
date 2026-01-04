# frozen_string_literal: true

require_relative "../../test_helper"

class PrismIRNodeAcceptTest < Test::Unit::TestCase
  class MockVisitor
    attr_reader :visited

    def initialize
      @visited = []
    end

    def method_missing(name, *args)
      @visited << name
      nil
    end

    def respond_to_missing?(*)
      true
    end
  end

  test "Block#accept calls visit_block" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Block.new([])
    node.accept(visitor)
    assert_equal [:visit_block], visitor.visited
  end

  test "VarDecl#accept calls visit_var_decl" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::VarDecl.new(:x, nil)
    node.accept(visitor)
    assert_equal [:visit_var_decl], visitor.visited
  end

  test "VarRef#accept calls visit_var_ref" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::VarRef.new(:x)
    node.accept(visitor)
    assert_equal [:visit_var_ref], visitor.visited
  end

  test "Literal#accept calls visit_literal" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Literal.new(1.0)
    node.accept(visitor)
    assert_equal [:visit_literal], visitor.visited
  end

  test "BoolLiteral#accept calls visit_bool_literal" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::BoolLiteral.new(true)
    node.accept(visitor)
    assert_equal [:visit_bool_literal], visitor.visited
  end

  test "BinaryOp#accept calls visit_binary_op" do
    visitor = MockVisitor.new
    left = RLSL::Prism::IR::Literal.new(1.0)
    right = RLSL::Prism::IR::Literal.new(2.0)
    node = RLSL::Prism::IR::BinaryOp.new("+", left, right)
    node.accept(visitor)
    assert_equal [:visit_binary_op], visitor.visited
  end

  test "UnaryOp#accept calls visit_unary_op" do
    visitor = MockVisitor.new
    operand = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::UnaryOp.new("-", operand)
    node.accept(visitor)
    assert_equal [:visit_unary_op], visitor.visited
  end

  test "FuncCall#accept calls visit_func_call" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::FuncCall.new(:sin, [])
    node.accept(visitor)
    assert_equal [:visit_func_call], visitor.visited
  end

  test "FieldAccess#accept calls visit_field_access" do
    visitor = MockVisitor.new
    receiver = RLSL::Prism::IR::VarRef.new(:v)
    node = RLSL::Prism::IR::FieldAccess.new(receiver, "x")
    node.accept(visitor)
    assert_equal [:visit_field_access], visitor.visited
  end

  test "Swizzle#accept calls visit_swizzle" do
    visitor = MockVisitor.new
    receiver = RLSL::Prism::IR::VarRef.new(:v)
    node = RLSL::Prism::IR::Swizzle.new(receiver, "xy")
    node.accept(visitor)
    assert_equal [:visit_swizzle], visitor.visited
  end

  test "IfStatement#accept calls visit_if_statement" do
    visitor = MockVisitor.new
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    then_branch = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::IfStatement.new(condition, then_branch)
    node.accept(visitor)
    assert_equal [:visit_if_statement], visitor.visited
  end

  test "Return#accept calls visit_return" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Return.new(nil)
    node.accept(visitor)
    assert_equal [:visit_return], visitor.visited
  end

  test "Assignment#accept calls visit_assignment" do
    visitor = MockVisitor.new
    target = RLSL::Prism::IR::VarRef.new(:x)
    value = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::Assignment.new(target, value)
    node.accept(visitor)
    assert_equal [:visit_assignment], visitor.visited
  end

  test "ForLoop#accept calls visit_for_loop" do
    visitor = MockVisitor.new
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::ForLoop.new(:i,
      RLSL::Prism::IR::Literal.new(0),
      RLSL::Prism::IR::Literal.new(10),
      body)
    node.accept(visitor)
    assert_equal [:visit_for_loop], visitor.visited
  end

  test "WhileLoop#accept calls visit_while_loop" do
    visitor = MockVisitor.new
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::WhileLoop.new(condition, body)
    node.accept(visitor)
    assert_equal [:visit_while_loop], visitor.visited
  end

  test "Break#accept calls visit_break" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Break.new
    node.accept(visitor)
    assert_equal [:visit_break], visitor.visited
  end

  test "Constant#accept calls visit_constant" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::Constant.new(:PI)
    node.accept(visitor)
    assert_equal [:visit_constant], visitor.visited
  end

  test "Parenthesized#accept calls visit_parenthesized" do
    visitor = MockVisitor.new
    expr = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::Parenthesized.new(expr)
    node.accept(visitor)
    assert_equal [:visit_parenthesized], visitor.visited
  end

  test "ArrayLiteral#accept calls visit_array_literal" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::ArrayLiteral.new([])
    node.accept(visitor)
    assert_equal [:visit_array_literal], visitor.visited
  end

  test "ArrayIndex#accept calls visit_array_index" do
    visitor = MockVisitor.new
    array = RLSL::Prism::IR::VarRef.new(:arr)
    index = RLSL::Prism::IR::Literal.new(0)
    node = RLSL::Prism::IR::ArrayIndex.new(array, index)
    node.accept(visitor)
    assert_equal [:visit_array_index], visitor.visited
  end

  test "GlobalDecl#accept calls visit_global_decl" do
    visitor = MockVisitor.new
    node = RLSL::Prism::IR::GlobalDecl.new(:MY_CONST, RLSL::Prism::IR::Literal.new(1.0))
    node.accept(visitor)
    assert_equal [:visit_global_decl], visitor.visited
  end

  test "FunctionDefinition#accept calls visit_function_definition" do
    visitor = MockVisitor.new
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::FunctionDefinition.new(:my_func, [], body)
    node.accept(visitor)
    assert_equal [:visit_function_definition], visitor.visited
  end

  test "MultipleAssignment#accept calls visit_multiple_assignment" do
    visitor = MockVisitor.new
    targets = [RLSL::Prism::IR::VarRef.new(:x), RLSL::Prism::IR::VarRef.new(:y)]
    value = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::MultipleAssignment.new(targets, value)
    node.accept(visitor)
    assert_equal [:visit_multiple_assignment], visitor.visited
  end
end

class PrismIRNodeTypeTest < Test::Unit::TestCase
  test "Literal infers float type from float value" do
    node = RLSL::Prism::IR::Literal.new(1.5)
    assert_equal :float, node.type
  end

  test "Literal infers int type from integer value" do
    node = RLSL::Prism::IR::Literal.new(1)
    assert_equal :int, node.type
  end

  test "Literal uses explicit type when provided" do
    node = RLSL::Prism::IR::Literal.new(1, :float)
    assert_equal :float, node.type
  end

  test "Return inherits expression type" do
    expr = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Return.new(expr)
    assert_equal :float, node.type
  end

  test "Return has nil type for empty return" do
    node = RLSL::Prism::IR::Return.new(nil)
    assert_nil node.type
  end

  test "Assignment inherits value type" do
    target = RLSL::Prism::IR::VarRef.new(:x)
    value = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Assignment.new(target, value)
    assert_equal :float, node.type
  end

  test "Parenthesized inherits expression type" do
    expr = RLSL::Prism::IR::Literal.new(1.0, :float)
    node = RLSL::Prism::IR::Parenthesized.new(expr)
    assert_equal :float, node.type
  end

  test "ForLoop has nil type" do
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::ForLoop.new(:i,
      RLSL::Prism::IR::Literal.new(0),
      RLSL::Prism::IR::Literal.new(10),
      body)
    assert_nil node.type
  end

  test "WhileLoop has nil type" do
    condition = RLSL::Prism::IR::BoolLiteral.new(true)
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::WhileLoop.new(condition, body)
    assert_nil node.type
  end

  test "Break has nil type" do
    node = RLSL::Prism::IR::Break.new
    assert_nil node.type
  end

  test "Constant has float type by default" do
    node = RLSL::Prism::IR::Constant.new(:PI)
    assert_equal :float, node.type
  end

  test "FunctionDefinition inherits return_type" do
    body = RLSL::Prism::IR::Block.new([])
    node = RLSL::Prism::IR::FunctionDefinition.new(:my_func, [], body, return_type: :vec3)
    assert_equal :vec3, node.type
  end
end

class PrismIRGlobalDeclTest < Test::Unit::TestCase
  test "GlobalDecl stores all properties" do
    init = RLSL::Prism::IR::Literal.new(1.0)
    node = RLSL::Prism::IR::GlobalDecl.new(
      :MY_CONST,
      init,
      type: :float,
      is_const: true,
      is_static: true,
      array_size: nil,
      element_type: nil
    )

    assert_equal :MY_CONST, node.name
    assert_equal init, node.initializer
    assert_equal :float, node.type
    assert_true node.is_const
    assert_true node.is_static
  end

  test "GlobalDecl supports array configuration" do
    elements = [
      RLSL::Prism::IR::Literal.new(1.0),
      RLSL::Prism::IR::Literal.new(2.0)
    ]
    init = RLSL::Prism::IR::ArrayLiteral.new(elements)
    node = RLSL::Prism::IR::GlobalDecl.new(
      :MY_ARRAY,
      init,
      array_size: 2,
      element_type: :float
    )

    assert_equal 2, node.array_size
    assert_equal :float, node.element_type
  end
end

class PrismIRTupleTypeTest < Test::Unit::TestCase
  test "TupleType stores types" do
    tuple = RLSL::Prism::IR::TupleType.new(:float, :float)
    assert_equal [:float, :float], tuple.types
  end

  test "TupleType to_sym generates symbol" do
    tuple = RLSL::Prism::IR::TupleType.new(:float, :vec2)
    assert_equal :tuple_float_vec2, tuple.to_sym
  end

  test "TupleType with multiple types" do
    tuple = RLSL::Prism::IR::TupleType.new(:float, :vec2, :vec3)
    assert_equal [:float, :vec2, :vec3], tuple.types
    assert_equal :tuple_float_vec2_vec3, tuple.to_sym
  end
end

class PrismIRNodeBaseTest < Test::Unit::TestCase
  test "Node#accept raises NotImplementedError" do
    node = RLSL::Prism::IR::Node.new
    assert_raise(NotImplementedError) do
      node.accept(nil)
    end
  end

  test "Node has type accessor" do
    node = RLSL::Prism::IR::Node.new
    node.type = :float
    assert_equal :float, node.type
  end
end
