# frozen_string_literal: true

module RLSL
  module Prism
    module Emitters
      class MSLEmitter < BaseEmitter
        TYPE_MAP = {
          float: "float",
          int: "int",
          bool: "bool",
          vec2: "float2",
          vec3: "float3",
          vec4: "float4",
          mat2: "float2x2",
          mat3: "float3x3",
          mat4: "float4x4",
          sampler2D: "texture2d<float>"
        }.freeze

        VECTOR_CONSTRUCTORS = {
          vec2: "float2",
          vec3: "float3",
          vec4: "float4"
        }.freeze

        MATRIX_CONSTRUCTORS = {
          mat2: "float2x2",
          mat3: "float3x3",
          mat4: "float4x4"
        }.freeze

        TEXTURE_FUNCTIONS = {
          texture2D: "sample",
          texture: "sample",
          textureLod: "sample"
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

          # MSL texture sampling: texture.sample(sampler, uv)
          if TEXTURE_FUNCTIONS.key?(name) && node.args.length >= 2
            texture = emit(node.args[0])
            uv = emit(node.args[1])
            return "#{texture}.sample(textureSampler, #{uv})"
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
