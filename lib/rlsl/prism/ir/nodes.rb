# frozen_string_literal: true

module RLSL
  module Prism
    module IR
      class Node
        attr_accessor :type

        def accept(visitor)
          raise NotImplementedError
        end
      end

      class Block < Node
        attr_reader :statements

        def initialize(statements = [])
          super()
          @statements = statements
        end

        def accept(visitor)
          visitor.visit_block(self)
        end
      end

      class VarDecl < Node
        attr_reader :name, :initializer

        def initialize(name, initializer, type = nil)
          super()
          @name = name
          @initializer = initializer
          @type = type
        end

        def accept(visitor)
          visitor.visit_var_decl(self)
        end
      end

      class VarRef < Node
        attr_reader :name

        def initialize(name, type = nil)
          super()
          @name = name
          @type = type
        end

        def accept(visitor)
          visitor.visit_var_ref(self)
        end
      end

      class Literal < Node
        attr_reader :value

        def initialize(value, type = nil)
          super()
          @value = value
          @type = type || (value.is_a?(Float) ? :float : :int)
        end

        def accept(visitor)
          visitor.visit_literal(self)
        end
      end

      class BoolLiteral < Node
        attr_reader :value

        def initialize(value)
          super()
          @value = value
          @type = :bool
        end

        def accept(visitor)
          visitor.visit_bool_literal(self)
        end
      end

      class BinaryOp < Node
        attr_reader :operator, :left, :right

        def initialize(operator, left, right, type = nil)
          super()
          @operator = operator
          @left = left
          @right = right
          @type = type
        end

        def accept(visitor)
          visitor.visit_binary_op(self)
        end
      end

      class UnaryOp < Node
        attr_reader :operator, :operand

        def initialize(operator, operand, type = nil)
          super()
          @operator = operator
          @operand = operand
          @type = type
        end

        def accept(visitor)
          visitor.visit_unary_op(self)
        end
      end

      class FuncCall < Node
        attr_reader :name, :args, :receiver

        def initialize(name, args = [], receiver = nil, type = nil)
          super()
          @name = name
          @args = args
          @receiver = receiver
          @type = type
        end

        def accept(visitor)
          visitor.visit_func_call(self)
        end
      end

      class FieldAccess < Node
        attr_reader :receiver, :field

        def initialize(receiver, field, type = nil)
          super()
          @receiver = receiver
          @field = field
          @type = type
        end

        def accept(visitor)
          visitor.visit_field_access(self)
        end
      end

      class Swizzle < Node
        attr_reader :receiver, :components

        def initialize(receiver, components, type = nil)
          super()
          @receiver = receiver
          @components = components
          @type = type
        end

        def accept(visitor)
          visitor.visit_swizzle(self)
        end
      end

      class IfStatement < Node
        attr_reader :condition, :then_branch, :else_branch

        def initialize(condition, then_branch, else_branch = nil, type = nil)
          super()
          @condition = condition
          @then_branch = then_branch
          @else_branch = else_branch
          @type = type
        end

        def accept(visitor)
          visitor.visit_if_statement(self)
        end
      end

      class Return < Node
        attr_reader :expression

        def initialize(expression)
          super()
          @expression = expression
          @type = expression&.type
        end

        def accept(visitor)
          visitor.visit_return(self)
        end
      end

      class Assignment < Node
        attr_reader :target, :value

        def initialize(target, value)
          super()
          @target = target
          @value = value
          @type = value&.type
        end

        def accept(visitor)
          visitor.visit_assignment(self)
        end
      end

      class ForLoop < Node
        attr_reader :variable, :range_start, :range_end, :body

        def initialize(variable, range_start, range_end, body)
          super()
          @variable = variable
          @range_start = range_start
          @range_end = range_end
          @body = body
          @type = nil
        end

        def accept(visitor)
          visitor.visit_for_loop(self)
        end
      end

      class WhileLoop < Node
        attr_reader :condition, :body

        def initialize(condition, body)
          super()
          @condition = condition
          @body = body
          @type = nil
        end

        def accept(visitor)
          visitor.visit_while_loop(self)
        end
      end

      class Break < Node
        def initialize
          super()
          @type = nil
        end

        def accept(visitor)
          visitor.visit_break(self)
        end
      end

      class Constant < Node
        attr_reader :name

        def initialize(name, type = :float)
          super()
          @name = name
          @type = type
        end

        def accept(visitor)
          visitor.visit_constant(self)
        end
      end

      class Parenthesized < Node
        attr_reader :expression

        def initialize(expression)
          super()
          @expression = expression
          @type = expression&.type
        end

        def accept(visitor)
          visitor.visit_parenthesized(self)
        end
      end

      class ArrayLiteral < Node
        attr_reader :elements

        def initialize(elements, type = nil)
          super()
          @elements = elements
          @type = type
        end

        def accept(visitor)
          visitor.visit_array_literal(self)
        end
      end

      class ArrayIndex < Node
        attr_reader :array, :index

        def initialize(array, index, type = nil)
          super()
          @array = array
          @index = index
          @type = type
        end

        def accept(visitor)
          visitor.visit_array_index(self)
        end
      end

      class GlobalDecl < Node
        attr_reader :name, :initializer
        attr_accessor :is_const, :is_static, :array_size, :element_type

        def initialize(name, initializer, type: nil, is_const: false, is_static: true, array_size: nil, element_type: nil)
          super()
          @name = name
          @initializer = initializer
          @type = type
          @is_const = is_const
          @is_static = is_static
          @array_size = array_size
          @element_type = element_type
        end

        def accept(visitor)
          visitor.visit_global_decl(self)
        end
      end

      class FunctionDefinition < Node
        attr_reader :name, :params, :body
        attr_accessor :return_type, :param_types

        def initialize(name, params, body, return_type: nil, param_types: {})
          super()
          @name = name
          @params = params
          @body = body
          @return_type = return_type
          @param_types = param_types
          @type = return_type
        end

        def accept(visitor)
          visitor.visit_function_definition(self)
        end
      end

      class MultipleAssignment < Node
        attr_reader :targets, :value

        def initialize(targets, value)
          super()
          @targets = targets
          @value = value
          @type = nil
        end

        def accept(visitor)
          visitor.visit_multiple_assignment(self)
        end
      end

      class TupleType
        attr_reader :types

        def initialize(*types)
          @types = types
        end

        def to_sym
          :"tuple_#{types.map(&:to_s).join('_')}"
        end
      end
    end
  end
end
