# frozen_string_literal: true

module RLSL
  module Prism
    class TypeInference
      attr_reader :symbol_table

      def initialize(uniforms = {}, custom_functions = {})
        @symbol_table = {}
        @uniforms = uniforms
        @custom_functions = custom_functions

        uniforms.each do |name, type|
          @symbol_table[name.to_sym] = type
        end
      end

      def register(name, type)
        @symbol_table[name.to_sym] = type
      end

      def register_function(name, returns:)
        @custom_functions[name.to_sym] = { returns: returns }
      end

      def lookup(name)
        @symbol_table[name.to_sym]
      end

      def infer(node)
        case node
        when IR::Block
          infer_block(node)
        when IR::VarDecl
          infer_var_decl(node)
        when IR::VarRef
          infer_var_ref(node)
        when IR::Literal
          infer_literal(node)
        when IR::BoolLiteral
          node.type = :bool
          node
        when IR::BinaryOp
          infer_binary_op(node)
        when IR::UnaryOp
          infer_unary_op(node)
        when IR::FuncCall
          infer_func_call(node)
        when IR::FieldAccess
          infer_field_access(node)
        when IR::Swizzle
          infer_swizzle(node)
        when IR::IfStatement
          infer_if_statement(node)
        when IR::Ternary
          infer_ternary(node)
        when IR::Return
          infer_return(node)
        when IR::Assignment
          infer_assignment(node)
        when IR::ForLoop
          infer_for_loop(node)
        when IR::WhileLoop
          infer_while_loop(node)
        when IR::Parenthesized
          infer_parenthesized(node)
        when IR::FunctionDefinition
          infer_function_definition(node)
        when IR::ArrayLiteral
          infer_array_literal(node)
        when IR::ArrayIndex
          infer_array_index(node)
        when IR::GlobalDecl
          infer_global_decl(node)
        when IR::MultipleAssignment
          infer_multiple_assignment(node)
        else
          node
        end
      end

      private

      def infer_block(node)
        node.statements.each { |stmt| infer(stmt) }
        node.type = node.statements.last&.type
        node
      end

      def infer_var_decl(node)
        infer(node.initializer) if node.initializer
        node.type ||= node.initializer&.type
        register(node.name, node.type) if node.type
        node
      end

      def infer_var_ref(node)
        node.type ||= lookup(node.name)
        node
      end

      def infer_literal(node)
        node
      end

      def infer_binary_op(node)
        infer(node.left)
        infer(node.right)

        node.type = Builtins.binary_op_result_type(
          node.operator,
          node.left.type,
          node.right.type
        )
        node
      end

      def infer_unary_op(node)
        infer(node.operand)

        case node.operator.to_s
        when "-"
          node.type = node.operand.type
        when "!"
          node.type = :bool
        end
        node
      end

      def infer_func_call(node)
        node.args.each { |arg| infer(arg) }
        infer(node.receiver) if node.receiver

        sig = Builtins.function_signature(node.name)
        if sig
          arg_types = node.args.map(&:type)
          node.type = Builtins.resolve_return_type(sig[:returns], arg_types)
        elsif @custom_functions.key?(node.name.to_sym)
          node.type = @custom_functions[node.name.to_sym][:returns]
        else
          node.type = node.receiver&.type
        end
        node
      end

      def infer_field_access(node)
        infer(node.receiver)

        if Builtins.single_component_field?(node.field)
          node.type = :float
        else
          node.type = @uniforms[node.field.to_sym] || :float
        end
        node
      end

      def infer_swizzle(node)
        infer(node.receiver)
        node.type = Builtins.swizzle_type(node.components)
        node
      end

      def infer_if_statement(node)
        infer(node.condition)
        infer(node.then_branch)
        infer(node.else_branch) if node.else_branch

        node.type = node.then_branch.type
        node
      end

      def infer_ternary(node)
        infer(node.condition)
        infer(node.then_expr)
        infer(node.else_expr)
        node.type = node.then_expr.type
        node
      end

      def infer_return(node)
        infer(node.expression) if node.expression
        node.type = node.expression&.type
        node
      end

      def infer_assignment(node)
        infer(node.target)
        infer(node.value)
        node.type = node.value.type
        node
      end

      def infer_for_loop(node)
        register(node.variable, :int)
        infer(node.range_start)
        infer(node.range_end)
        infer(node.body)
        node.type = nil
        node
      end

      def infer_while_loop(node)
        infer(node.condition)
        infer(node.body)
        node.type = nil
        node
      end

      def infer_function_definition(node)
        node.param_types.each do |param_name, param_type|
          register(param_name, param_type)
        end

        infer(node.body)

        node.return_type ||= node.body&.type
        node.type = node.return_type
        node
      end

      def infer_parenthesized(node)
        infer(node.expression)
        node.type = node.expression.type
        node
      end

      def infer_array_literal(node)
        node.elements.each { |elem| infer(elem) }

        element_type = node.elements.first&.type || :float
        node.type = :"array_#{element_type}"
        node
      end

      def infer_array_index(node)
        infer(node.array)
        infer(node.index)

        array_type = node.array.type
        if array_type.to_s.start_with?("array_")
          node.type = array_type.to_s.sub("array_", "").to_sym
        else
          node.type = @symbol_table["#{node.array.name}_element_type".to_sym] || :float
        end
        node
      end

      def infer_global_decl(node)
        infer(node.initializer) if node.initializer

        if node.initializer.is_a?(IR::ArrayLiteral)
          node.array_size ||= node.initializer.elements.length
          first_elem = node.initializer.elements.first
          node.element_type ||= first_elem&.type || :float
          node.type = :"array_#{node.element_type}"
        else
          node.type ||= node.initializer&.type
        end

        register(node.name, node.type) if node.type

        if node.element_type
          register("#{node.name}_element_type".to_sym, node.element_type)
        end

        node
      end

      def infer_multiple_assignment(node)
        infer(node.value)

        value_type = node.value.type
        if value_type.is_a?(IR::TupleType)
          node.targets.each_with_index do |target, i|
            target.type = value_type.types[i]
            register(target.name, target.type)
          end
        elsif value_type.to_s.start_with?("array_")
          elem_type = value_type.to_s.sub("array_", "").to_sym
          node.targets.each do |target|
            target.type = elem_type
            register(target.name, target.type)
          end
        elsif @custom_functions.key?(node.value.name) && node.value.is_a?(IR::FuncCall)
          func_info = @custom_functions[node.value.name]
          if func_info[:returns].is_a?(Array)
            node.targets.each_with_index do |target, i|
              target.type = func_info[:returns][i]
              register(target.name, target.type)
            end
          end
        end

        node.type = nil
        node
      end
    end
  end
end
