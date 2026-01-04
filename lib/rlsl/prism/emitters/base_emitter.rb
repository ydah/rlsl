# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class BaseEmitter
        PRECEDENCE = {
          "||" => 1,
          "&&" => 2,
          "==" => 3, "!=" => 3,
          "<" => 4, ">" => 4, "<=" => 4, ">=" => 4,
          "+" => 5, "-" => 5,
          "*" => 6, "/" => 6, "%" => 6
        }.freeze

        attr_reader :indent_level

        def initialize
          @indent_level = 0
        end

        def emit(node, needs_return: false)
          case node
          when IR::Block
            emit_block(node, needs_return: needs_return)
          when IR::VarDecl
            emit_var_decl(node)
          when IR::VarRef
            emit_var_ref(node)
          when IR::Literal
            emit_literal(node)
          when IR::BoolLiteral
            emit_bool_literal(node)
          when IR::BinaryOp
            emit_binary_op(node)
          when IR::UnaryOp
            emit_unary_op(node)
          when IR::FuncCall
            emit_func_call(node)
          when IR::FieldAccess
            emit_field_access(node)
          when IR::Swizzle
            emit_swizzle(node)
          when IR::IfStatement
            emit_if_statement(node)
          when IR::Return
            emit_return(node)
          when IR::Assignment
            emit_assignment(node)
          when IR::ForLoop
            emit_for_loop(node)
          when IR::WhileLoop
            emit_while_loop(node)
          when IR::Break
            emit_break(node)
          when IR::Constant
            emit_constant(node)
          when IR::Parenthesized
            emit_parenthesized(node)
          when IR::FunctionDefinition
            emit_function_definition(node)
          when IR::ArrayLiteral
            emit_array_literal(node)
          when IR::ArrayIndex
            emit_array_index(node)
          when IR::GlobalDecl
            emit_global_decl(node)
          when IR::MultipleAssignment
            emit_multiple_assignment(node)
          else
            raise "Unknown IR node: #{node.class}"
          end
        end

        protected

        def type_name(type)
          type.to_s
        end

        def emit_block(node, needs_return: false)
          statements = node.statements
          return "" if statements.empty?

          if needs_return && statements.any?
            result = statements[0...-1].map { |stmt| emit_statement(stmt) }.join
            result + emit_with_return(statements.last)
          else
            statements.map { |stmt| emit_statement(stmt) }.join
          end
        end

        def emit_with_return(node)
          if node.is_a?(IR::IfStatement)
            emit_if_with_return(node)
          elsif node.is_a?(IR::Return)
            emit_statement(node)
          elsif node.is_a?(IR::FunctionDefinition) || node.is_a?(IR::GlobalDecl) ||
                node.is_a?(IR::MultipleAssignment)
            emit_statement(node)
          elsif node.is_a?(IR::ArrayLiteral)
            emit_tuple_return(node)
          else
            "#{indent}return #{emit(node)};\n"
          end
        end

        def emit_tuple_return(node)
          elements = node.elements.map { |elem| emit(elem) }.join(", ")
          "#{indent}return (#{current_return_struct_name}){#{elements}};\n"
        end

        def emit_if_with_return(node)
          condition = emit(node.condition)
          then_code = emit_branch_with_return(node.then_branch)

          if node.else_branch
            if elsif_node?(node.else_branch)
              elsif_code = emit_elsif_with_return(node.else_branch)
              "#{indent}if (#{condition}) {\n#{then_code}#{indent}} #{elsif_code}\n"
            else
              else_code = emit_branch_with_return(node.else_branch)
              "#{indent}if (#{condition}) {\n#{then_code}#{indent}} else {\n#{else_code}#{indent}}\n"
            end
          else
            "#{indent}if (#{condition}) {\n#{then_code}#{indent}}\n"
          end
        end

        def emit_elsif_with_return(node)
          if_node = node.is_a?(IR::Block) ? node.statements.first : node
          condition = emit(if_node.condition)
          then_code = emit_branch_with_return(if_node.then_branch)

          if if_node.else_branch
            if elsif_node?(if_node.else_branch)
              elsif_code = emit_elsif_with_return(if_node.else_branch)
              "else if (#{condition}) {\n#{then_code}#{indent}} #{elsif_code}"
            else
              else_code = emit_branch_with_return(if_node.else_branch)
              "else if (#{condition}) {\n#{then_code}#{indent}} else {\n#{else_code}#{indent}}"
            end
          else
            "else if (#{condition}) {\n#{then_code}#{indent}}"
          end
        end

        def emit_branch_with_return(node)
          @indent_level += 1
          result = if node.is_a?(IR::Block)
                     emit_block(node, needs_return: true)
                   else
                     emit_with_return(node)
                   end
          @indent_level -= 1
          result
        end

        def emit_statement(node, needs_return: false)
          if needs_return && !node.is_a?(IR::Return) && !node.is_a?(IR::IfStatement) &&
             !node.is_a?(IR::ForLoop) && !node.is_a?(IR::WhileLoop) && !node.is_a?(IR::VarDecl) &&
             !node.is_a?(IR::Assignment) && !node.is_a?(IR::FunctionDefinition) &&
             !node.is_a?(IR::GlobalDecl) && !node.is_a?(IR::MultipleAssignment)
            return "#{indent}return #{emit(node)};\n"
          end

          code = emit(node)
          if node.is_a?(IR::IfStatement) || node.is_a?(IR::ForLoop) ||
             node.is_a?(IR::WhileLoop) || node.is_a?(IR::FunctionDefinition)
            "#{indent}#{code}\n"
          else
            "#{indent}#{code};\n"
          end
        end

        def emit_var_decl(node)
          type = type_name(node.type || :float)
          value = emit(node.initializer)
          "#{type} #{node.name} = #{value}"
        end

        def emit_var_ref(node)
          node.name.to_s
        end

        def emit_literal(node)
          format_number(node.value)
        end

        def emit_bool_literal(node)
          node.value.to_s
        end

        def emit_binary_op(node)
          left = emit_with_precedence(node.left, node.operator)
          right = emit_with_precedence(node.right, node.operator)
          "#{left} #{node.operator} #{right}"
        end

        def emit_unary_op(node)
          operand = emit(node.operand)
          "#{node.operator}#{operand}"
        end

        def emit_func_call(node)
          func_name = function_name(node.name)
          args = node.args.map { |arg| emit(arg) }.join(", ")

          if node.receiver
            receiver = emit(node.receiver)
            "#{func_name}(#{receiver}, #{args})"
          else
            "#{func_name}(#{args})"
          end
        end

        def emit_field_access(node)
          receiver = emit(node.receiver)
          "#{receiver}.#{node.field}"
        end

        def emit_swizzle(node)
          receiver = emit(node.receiver)
          "#{receiver}.#{node.components}"
        end

        def emit_if_statement(node)
          condition = emit(node.condition)
          then_code = emit_indented_block(node.then_branch)

          if node.else_branch
            if elsif_node?(node.else_branch)
              elsif_code = emit_elsif(node.else_branch)
              "if (#{condition}) {\n#{then_code}#{indent}} #{elsif_code}"
            else
              else_code = emit_indented_block(node.else_branch)
              "if (#{condition}) {\n#{then_code}#{indent}} else {\n#{else_code}#{indent}}"
            end
          else
            "if (#{condition}) {\n#{then_code}#{indent}}"
          end
        end

        def elsif_node?(node)
          return true if node.is_a?(IR::IfStatement)
          return false unless node.is_a?(IR::Block)

          node.statements.length == 1 && node.statements.first.is_a?(IR::IfStatement)
        end

        def emit_elsif(node)
          if_node = node.is_a?(IR::Block) ? node.statements.first : node
          condition = emit(if_node.condition)
          then_code = emit_indented_block(if_node.then_branch)

          if if_node.else_branch
            if elsif_node?(if_node.else_branch)
              elsif_code = emit_elsif(if_node.else_branch)
              "else if (#{condition}) {\n#{then_code}#{indent}} #{elsif_code}"
            else
              else_code = emit_indented_block(if_node.else_branch)
              "else if (#{condition}) {\n#{then_code}#{indent}} else {\n#{else_code}#{indent}}"
            end
          else
            "else if (#{condition}) {\n#{then_code}#{indent}}"
          end
        end

        def emit_return(node)
          if node.expression
            "return #{emit(node.expression)}"
          else
            "return"
          end
        end

        def emit_assignment(node)
          target = emit(node.target)
          value = emit(node.value)
          "#{target} = #{value}"
        end

        def emit_for_loop(node)
          var = node.variable
          start_val = emit(node.range_start)
          end_val = emit(node.range_end)
          body = emit_indented_block(node.body)

          "for (int #{var} = #{start_val}; #{var} < #{end_val}; #{var}++) {\n#{body}#{indent}}"
        end

        def emit_while_loop(node)
          condition = emit(node.condition)
          body = emit_indented_block(node.body)

          "while (#{condition}) {\n#{body}#{indent}}"
        end

        def emit_break(_node)
          "break"
        end

        def emit_constant(node)
          case node.name
          when :PI
            "3.14159265358979323846"
          when :TAU
            "6.28318530717958647692"
          else
            node.name.to_s
          end
        end

        def emit_parenthesized(node)
          "(#{emit(node.expression)})"
        end

        def emit_function_definition(node)
          name = node.name
          params = node.params.map do |param|
            param_type = type_name(node.param_types[param] || :float)
            "#{param_type} #{param}"
          end.join(", ")

          if node.return_type.is_a?(Array)
            @current_return_struct_name = "#{name}_result"
            struct_def = emit_result_struct(name, node.return_type)

            body = emit_indented_block(node.body, needs_return: true)

            @current_return_struct_name = nil
            "#{struct_def}static inline #{name}_result #{name}(#{params}) {\n#{body}\n#{indent}}\n"
          else
            return_type = type_name(node.return_type || :float)

            body = emit_indented_block(node.body, needs_return: true)

            "static inline #{return_type} #{name}(#{params}) {\n#{body}\n#{indent}}\n"
          end
        end

        def emit_result_struct(func_name, types)
          fields = types.each_with_index.map do |t, i|
            "#{type_name(t)} v#{i};"
          end.join(" ")
          "typedef struct { #{fields} } #{func_name}_result;\n"
        end

        def current_return_struct_name
          @current_return_struct_name || "result"
        end

        def emit_array_literal(node, for_static_init: false)
          elements = node.elements.map { |elem| emit_for_static_init(elem, for_static_init) }.join(", ")
          "{#{elements}}"
        end

        def emit_for_static_init(node, for_static_init)
          return emit(node) unless for_static_init

          case node
          when IR::FuncCall
            if %i[vec2 vec3 vec4].include?(node.name)
              args = node.args.map { |arg| emit_for_static_init(arg, true) }.join(", ")
              "{#{args}}"
            else
              emit(node)
            end
          when IR::ArrayLiteral
            emit_array_literal(node, for_static_init: true)
          else
            emit(node)
          end
        end

        def emit_array_index(node)
          array = emit(node.array)
          index = if node.index.is_a?(IR::Literal) && node.index.value.to_i == node.index.value
                    node.index.value.to_i.to_s
                  else
                    emit(node.index)
                  end
          "#{array}[#{index}]"
        end

        def emit_global_decl(node)
          name = node.name

          if node.initializer.is_a?(IR::ArrayLiteral)
            elem_type = type_name(node.element_type || :float)
            size = node.array_size || node.initializer.elements.length
            elements = emit_array_literal(node.initializer, for_static_init: true)

            prefix = ""
            prefix += "static " if node.is_static
            prefix += "const " if node.is_const

            "#{prefix}#{elem_type} #{name}[#{size}] = #{elements}"
          else
            var_type = type_name(node.type || :float)
            value = if node.is_const
                      emit_for_static_init(node.initializer, true)
                    else
                      emit(node.initializer)
                    end

            prefix = ""
            prefix += "static " if node.is_static
            prefix += "const " if node.is_const

            "#{prefix}#{var_type} #{name} = #{value}"
          end
        end

        def emit_multiple_assignment(node)
          value_code = emit(node.value)

          if node.value.is_a?(IR::FuncCall)
            func_name = node.value.name
            struct_name = "#{func_name}_result"

            lines = []
            lines << "#{struct_name} _tmp_#{func_name} = #{value_code}"
            node.targets.each_with_index do |target, i|
              target_type = type_name(target.type || :float)
              lines << "#{target_type} #{target.name} = _tmp_#{func_name}.v#{i}"
            end
            lines.join(";\n#{indent}")
          else
            lines = []
            node.targets.each_with_index do |target, i|
              target_type = type_name(target.type || :float)
              lines << "#{target_type} #{target.name} = #{value_code}[#{i}]"
            end
            lines.join(";\n#{indent}")
          end
        end

        def format_number(value)
          if value.is_a?(Float)
            formatted = value.to_s
            formatted += ".0" unless formatted.include?(".")
            formatted
          else
            "#{value}.0"
          end
        end

        def indent
          "  " * @indent_level
        end

        def emit_indented_block(node, needs_return: false)
          @indent_level += 1
          result = if node.is_a?(IR::Block)
                     emit_block(node, needs_return: needs_return)
                   else
                     emit_statement(node, needs_return: needs_return)
                   end
          @indent_level -= 1
          result
        end

        def emit_with_precedence(node, parent_op)
          code = emit(node)
          if node.is_a?(IR::BinaryOp)
            node_prec = PRECEDENCE[node.operator] || 10
            parent_prec = PRECEDENCE[parent_op] || 10
            return "(#{code})" if node_prec < parent_prec
          end
          code
        end

        def function_name(name)
          name.to_s
        end
      end
    end
  end
end
