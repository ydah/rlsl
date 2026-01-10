# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class WGSLEmitter < BaseEmitter
        TYPE_MAP = {
          float: "f32",
          int: "i32",
          bool: "bool",
          vec2: "vec2<f32>",
          vec3: "vec3<f32>",
          vec4: "vec4<f32>",
          mat2: "mat2x2<f32>",
          mat3: "mat3x3<f32>",
          mat4: "mat4x4<f32>",
          sampler2D: "texture_2d<f32>"
        }.freeze

        VECTOR_CONSTRUCTORS = {
          vec2: "vec2<f32>",
          vec3: "vec3<f32>",
          vec4: "vec4<f32>"
        }.freeze

        MATRIX_CONSTRUCTORS = {
          mat2: "mat2x2<f32>",
          mat3: "mat3x3<f32>",
          mat4: "mat4x4<f32>"
        }.freeze

        TEXTURE_FUNCTIONS = {
          texture2D: "textureSample",
          texture: "textureSample",
          textureLod: "textureSampleLevel"
        }.freeze

        protected

        def type_name(type)
          TYPE_MAP[type&.to_sym] || "f32"
        end

        def emit_var_decl(node)
          type = type_name(node.type || :float)
          value = emit(node.initializer)
          "let #{node.name}: #{type} = #{value}"
        end

        def emit_func_call(node)
          name = node.name.to_sym

          if VECTOR_CONSTRUCTORS.key?(name)
            args = node.args.map { |arg| emit(arg) }.join(", ")
            return "#{VECTOR_CONSTRUCTORS[name]}(#{args})"
          end

          if MATRIX_CONSTRUCTORS.key?(name)
            args = node.args.map { |arg| emit(arg) }.join(", ")
            return "#{MATRIX_CONSTRUCTORS[name]}(#{args})"
          end

          if TEXTURE_FUNCTIONS.key?(name)
            args = node.args.map { |arg| emit(arg) }.join(", ")
            return "#{TEXTURE_FUNCTIONS[name]}(#{args})"
          end

          args = node.args.map { |arg| emit(arg) }.join(", ")
          "#{name}(#{args})"
        end

        def emit_for_loop(node)
          var = node.variable
          start_val = emit(node.range_start)
          end_val = emit(node.range_end)
          body = emit_indented_block(node.body)

          "for (var #{var}: i32 = #{start_val}; #{var} < #{end_val}; #{var}++) {\n#{body}#{indent}}"
        end

        def emit_ternary(node)
          condition = emit(node.condition)
          then_expr = emit(node.then_expr)
          else_expr = emit(node.else_expr)
          "select(#{else_expr}, #{then_expr}, #{condition})"
        end

        def emit_binary_op(node)
          left = emit_with_precedence(node.left, node.operator)
          right = emit_with_precedence(node.right, node.operator)
          "#{left} #{node.operator} #{right}"
        end
      end
    end
  end
end
