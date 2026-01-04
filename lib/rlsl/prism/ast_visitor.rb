# frozen_string_literal: true

require "prism"
require "set"

module RLSL
  module Prism
    class ASTVisitor
      BINARY_OPERATORS = %w[+ - * / % == != < > <= >= && ||].freeze
      UNARY_OPERATORS = %w[- !].freeze

      def initialize(context = {})
        @context = context
        @uniforms = context[:uniforms] || {}
        @params = Set.new(context[:params] || [])
        @declared_vars = Set.new
      end

      def parse(source)
        result = ::Prism.parse(source)

        unless result.success?
          errors = result.errors.map(&:message).join(", ")
          raise "Parse error: #{errors}"
        end

        program = result.value
        visit(program)
      end

      def visit(node)
        return nil if node.nil?

        method_name = "visit_#{node_type(node)}"
        if respond_to?(method_name, true)
          send(method_name, node)
        else
          visit_default(node)
        end
      end

      private

      def node_type(node)
        node.class.name.split("::").last
          .gsub(/Node$/, "")
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
      end

      def visit_default(node)
        children = []
        node.child_nodes.compact.each do |child|
          result = visit(child)
          children << result if result
        end
        children.length == 1 ? children.first : children
      end

      def visit_program(node)
        visit(node.statements)
      end

      def visit_statements(node)
        statements = node.body.map { |stmt| visit(stmt) }.compact.flatten
        IR::Block.new(statements)
      end

      def visit_block(node)
        if node.parameters
          node.parameters.parameters&.requireds&.each do |param|
            @params.add(param.name.to_sym)
          end
        end

        visit(node.body)
      end

      def visit_lambda(node)
        visit_block(node)
      end

      def visit_local_variable_write(node)
        name = node.name.to_sym
        value = visit(node.value)

        if @declared_vars.include?(name) || @params.include?(name)
          IR::Assignment.new(IR::VarRef.new(name), value)
        else
          @declared_vars.add(name)
          IR::VarDecl.new(name, value)
        end
      end

      def visit_local_variable_read(node)
        name = node.name.to_sym
        type = infer_param_type(name)
        IR::VarRef.new(name, type)
      end

      def visit_integer(node)
        IR::Literal.new(node.value.to_f, :float)
      end

      def visit_float(node)
        IR::Literal.new(node.value, :float)
      end

      def visit_rational(node)
        IR::Literal.new(node.value.to_f, :float)
      end

      def visit_true(node)
        IR::BoolLiteral.new(true)
      end

      def visit_false(node)
        IR::BoolLiteral.new(false)
      end

      def visit_parentheses(node)
        inner = visit(node.body)
        if inner.is_a?(IR::Block) && inner.statements.length == 1
          inner = inner.statements.first
        end
        IR::Parenthesized.new(inner)
      end

      def visit_call(node)
        method_name = node.name.to_s
        receiver = visit(node.receiver) if node.receiver
        args = node.arguments&.arguments&.map { |arg| visit(arg) } || []

        if !receiver && args.empty? && @params.include?(method_name.to_sym)
          type = infer_param_type(method_name.to_sym)
          return IR::VarRef.new(method_name.to_sym, type)
        end

        if receiver && args.empty? && !node.arguments
          if Builtins.single_component_field?(method_name)
            return IR::FieldAccess.new(receiver, method_name, :float)
          elsif Builtins.swizzle?(method_name)
            type = Builtins.swizzle_type(method_name)
            return IR::Swizzle.new(receiver, method_name, type)
          else
            return IR::FieldAccess.new(receiver, method_name)
          end
        end

        if BINARY_OPERATORS.include?(method_name) && receiver && args.length == 1
          return IR::BinaryOp.new(method_name, receiver, args.first)
        end

        if method_name == "-@" && receiver
          return IR::UnaryOp.new("-", receiver)
        end
        if method_name == "!" && args.length == 1
          return IR::UnaryOp.new("!", args.first)
        end

        if method_name == "[]" && receiver && args.length == 1
          return IR::ArrayIndex.new(receiver, args.first)
        end

        IR::FuncCall.new(method_name.to_sym, args, receiver)
      end

      def visit_if(node)
        condition = visit(node.predicate)
        then_branch = visit_with_scoped_vars(node.statements)
        else_branch = node.subsequent ? visit_with_scoped_vars(node.subsequent) : nil

        IR::IfStatement.new(condition, then_branch, else_branch)
      end

      def visit_with_scoped_vars(node)
        saved_vars = @declared_vars.dup
        result = visit(node)
        @declared_vars = saved_vars
        result
      end

      def visit_else(node)
        visit(node.statements)
      end

      def visit_elsif(node)
        visit_if(node)
      end

      def visit_if_node(node)
        visit_if(node)
      end

      def visit_unless(node)
        condition = IR::UnaryOp.new("!", visit(node.predicate))
        then_branch = visit(node.statements)
        else_branch = node.else_clause ? visit(node.else_clause) : nil

        IR::IfStatement.new(condition, then_branch, else_branch)
      end

      def visit_return(node)
        expr = node.arguments ? visit(node.arguments.arguments.first) : nil
        IR::Return.new(expr)
      end

      def visit_range(node)
        [visit(node.left), visit(node.right)]
      end

      def visit_for(node)
        var_name = node.index.name.to_sym
        range = visit(node.collection)
        body = visit(node.statements)

        IR::ForLoop.new(var_name, range[0], range[1], body)
      end

      def visit_call_with_block(node)
        call_node = node
        method_name = call_node.name.to_s

        if method_name == "times" && call_node.receiver
          count = visit(call_node.receiver)
          block = visit(call_node.block)

          var_name = :i
          if call_node.block&.parameters&.parameters&.requireds&.any?
            var_name = call_node.block.parameters.parameters.requireds.first.name.to_sym
          end

          IR::ForLoop.new(var_name, IR::Literal.new(0, :int), count, block)
        else
          visit_call(node)
        end
      end

      def visit_and(node)
        left = visit(node.left)
        right = visit(node.right)
        IR::BinaryOp.new("&&", left, right, :bool)
      end

      def visit_or(node)
        left = visit(node.left)
        right = visit(node.right)
        IR::BinaryOp.new("||", left, right, :bool)
      end

      def visit_not(node)
        operand = visit(node.expression)
        IR::UnaryOp.new("!", operand, :bool)
      end

      def visit_while(node)
        condition = visit(node.predicate)
        body = visit(node.statements)
        IR::WhileLoop.new(condition, body)
      end

      def visit_break(node)
        IR::Break.new
      end

      def visit_constant_read(node)
        name = node.name.to_s
        if %w[PI TAU].include?(name)
          IR::Constant.new(name.to_sym, :float)
        else
          IR::VarRef.new(name.to_sym)
        end
      end

      def visit_def(node)
        name = node.name.to_sym
        params = []

        if node.parameters
          node.parameters.requireds&.each do |param|
            params << param.name.to_sym
          end
        end

        saved_params = @params.dup
        saved_declared_vars = @declared_vars.dup
        @declared_vars = Set.new
        params.each { |p| @params.add(p) }

        body = visit(node.body)

        @params = saved_params
        @declared_vars = saved_declared_vars

        IR::FunctionDefinition.new(name, params, body)
      end

      def visit_array(node)
        elements = node.elements.map { |elem| visit(elem) }
        IR::ArrayLiteral.new(elements)
      end

      def visit_index(node)
        array = visit(node.receiver)
        index = visit(node.arguments.arguments.first)
        IR::ArrayIndex.new(array, index)
      end

      def visit_constant_path(node)
        path_parts = []
        current = node
        while current.is_a?(::Prism::ConstantPathNode)
          path_parts.unshift(current.name.to_s)
          current = current.parent
        end
        path_parts.unshift(current.name.to_s) if current.respond_to?(:name)

        full_name = path_parts.join("_")
        IR::VarRef.new(full_name.to_sym)
      end

      def visit_global_variable_read(node)
        name = node.name.to_s.sub(/^\$/, "").to_sym
        IR::VarRef.new(name)
      end

      def visit_global_variable_write(node)
        name = node.name.to_s.sub(/^\$/, "").to_sym
        value = visit(node.value)

        IR::GlobalDecl.new(name, value, is_static: true)
      end

      def visit_constant_write(node)
        name = node.name.to_sym
        value = visit(node.value)

        IR::GlobalDecl.new(name, value, is_const: true, is_static: true)
      end

      def visit_multi_write(node)
        targets = node.lefts.map do |target|
          name = target.name.to_sym
          @declared_vars.add(name)
          IR::VarRef.new(name)
        end

        value = visit(node.value)
        IR::MultipleAssignment.new(targets, value)
      end

      def visit_local_variable_target(node)
        name = node.name.to_sym
        @declared_vars.add(name)
        IR::VarRef.new(name)
      end

      def infer_param_type(name)
        case name
        when :frag_coord, :resolution
          :vec2
        when :u
          :uniforms
        else
          nil
        end
      end
    end
  end
end
