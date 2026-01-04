# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class GLSLEmitter < BaseEmitter
        TYPE_MAP = {
          float: "float",
          int: "int",
          bool: "bool",
          vec2: "vec2",
          vec3: "vec3",
          vec4: "vec4",
          mat2: "mat2",
          mat3: "mat3",
          mat4: "mat4",
          sampler2D: "sampler2D"
        }.freeze

        VECTOR_CONSTRUCTORS = {
          vec2: "vec2",
          vec3: "vec3",
          vec4: "vec4"
        }.freeze

        MATRIX_CONSTRUCTORS = {
          mat2: "mat2",
          mat3: "mat3",
          mat4: "mat4"
        }.freeze

        TEXTURE_FUNCTIONS = {
          texture2D: "texture2D",
          texture: "texture",
          textureLod: "textureLod"
        }.freeze

        protected

        def type_name(type)
          TYPE_MAP[type&.to_sym] || "float"
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

        def emit_binary_op(node)
          left = emit_with_precedence(node.left, node.operator)
          right = emit_with_precedence(node.right, node.operator)
          "#{left} #{node.operator} #{right}"
        end
      end
    end
  end
end
