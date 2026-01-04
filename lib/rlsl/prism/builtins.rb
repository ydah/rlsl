# frozen_string_literal: true

module RLSL
  module Prism
    module Builtins
      FUNCTIONS = {
        vec2: { args: %i[any any], returns: :vec2, variadic: true, min_args: 1 },
        vec3: { args: %i[any any any], returns: :vec3, variadic: true, min_args: 1 },
        vec4: { args: %i[any any any any], returns: :vec4, variadic: true, min_args: 1 },

        mat2: { args: %i[any any any any], returns: :mat2, variadic: true, min_args: 1 },
        mat3: { args: %i[any any any any any any any any any], returns: :mat3, variadic: true, min_args: 1 },
        mat4: { args: %i[any any any any any any any any any any any any any any any any], returns: :mat4, variadic: true, min_args: 1 },

        sin: { args: [:float], returns: :float },
        cos: { args: [:float], returns: :float },
        tan: { args: [:float], returns: :float },
        asin: { args: [:float], returns: :float },
        acos: { args: [:float], returns: :float },
        atan: { args: %i[float float], returns: :float, variadic: true, min_args: 1 },
        atan2: { args: %i[float float], returns: :float },

        pow: { args: %i[float float], returns: :float },
        exp: { args: [:float], returns: :float },
        log: { args: [:float], returns: :float },
        sqrt: { args: [:any], returns: :same },

        abs: { args: [:any], returns: :same },
        sign: { args: [:any], returns: :same },
        floor: { args: [:any], returns: :same },
        ceil: { args: [:any], returns: :same },
        fract: { args: [:any], returns: :same },
        mod: { args: %i[any float], returns: :first },
        min: { args: %i[any any], returns: :first },
        max: { args: %i[any any], returns: :first },
        clamp: { args: %i[any any any], returns: :first },
        mix: { args: %i[any any float], returns: :first },
        step: { args: %i[float any], returns: :second },
        smoothstep: { args: %i[float float any], returns: :third },

        length: { args: [:any], returns: :float },
        distance: { args: %i[any any], returns: :float },
        dot: { args: %i[any any], returns: :float },
        cross: { args: %i[vec3 vec3], returns: :vec3 },
        normalize: { args: [:any], returns: :same },
        reflect: { args: %i[any any], returns: :first },
        refract: { args: %i[any any float], returns: :first },

        hash21: { args: [:vec2], returns: :float },
        hash22: { args: [:vec2], returns: :vec2 },

        lessThan: { args: %i[any any], returns: :bool },
        lessThanEqual: { args: %i[any any], returns: :bool },
        greaterThan: { args: %i[any any], returns: :bool },
        greaterThanEqual: { args: %i[any any], returns: :bool },
        equal: { args: %i[any any], returns: :bool },
        notEqual: { args: %i[any any], returns: :bool },

        inverse: { args: [:any], returns: :same },
        transpose: { args: [:any], returns: :same },
        determinant: { args: [:any], returns: :float },

        texture2D: { args: %i[sampler2D vec2], returns: :vec4 },
        texture: { args: %i[sampler2D vec2], returns: :vec4 },
        textureLod: { args: %i[sampler2D vec2 float], returns: :vec4 }
      }.freeze

      BINARY_OPERATORS = {
        "+" => :arithmetic,
        "-" => :arithmetic,
        "*" => :arithmetic,
        "/" => :arithmetic,
        "%" => :arithmetic,

        "==" => :comparison,
        "!=" => :comparison,
        "<" => :comparison,
        ">" => :comparison,
        "<=" => :comparison,
        ">=" => :comparison,

        "&&" => :logical,
        "||" => :logical
      }.freeze

      UNARY_OPERATORS = {
        "-" => :negate,
        "!" => :not
      }.freeze

      SWIZZLE_COMPONENTS = {
        "x" => 0, "r" => 0, "s" => 0,
        "y" => 1, "g" => 1, "t" => 1,
        "z" => 2, "b" => 2, "p" => 2,
        "w" => 3, "a" => 3, "q" => 3
      }.freeze

      SINGLE_COMPONENT_FIELDS = %w[x y z w r g b a s t p q].freeze

      SWIZZLE_PATTERNS = /\A[xyzwrgba]{2,4}\z/

      class << self
        def function?(name)
          FUNCTIONS.key?(name.to_sym)
        end

        def function_signature(name)
          FUNCTIONS[name.to_sym]
        end

        def binary_operator?(op)
          BINARY_OPERATORS.key?(op.to_s)
        end

        def unary_operator?(op)
          UNARY_OPERATORS.key?(op.to_s)
        end

        def single_component_field?(name)
          SINGLE_COMPONENT_FIELDS.include?(name.to_s)
        end

        def swizzle?(name)
          name.to_s.match?(SWIZZLE_PATTERNS)
        end

        def swizzle_type(components)
          case components.length
          when 2 then :vec2
          when 3 then :vec3
          when 4 then :vec4
          else :float
          end
        end

        def resolve_return_type(rule, arg_types)
          case rule
          when :same then arg_types.first
          when :first then arg_types.first
          when :second then arg_types[1]
          when :third then arg_types[2]
          when Symbol then rule
          end
        end

        def binary_op_result_type(op, left_type, right_type)
          op_kind = BINARY_OPERATORS[op.to_s]

          case op_kind
          when :comparison, :logical
            :bool
          when :arithmetic
            if matrix_type?(left_type) && vector_type?(right_type)
              matrix_vector_result(left_type)
            elsif vector_type?(left_type) && matrix_type?(right_type)
              matrix_vector_result(right_type)
            elsif matrix_type?(left_type) && matrix_type?(right_type)
              left_type
            elsif matrix_type?(left_type) && scalar_type?(right_type)
              left_type
            elsif scalar_type?(left_type) && matrix_type?(right_type)
              right_type
            elsif vector_type?(left_type) && vector_type?(right_type)
              left_type
            elsif vector_type?(left_type) && scalar_type?(right_type)
              left_type
            elsif scalar_type?(left_type) && vector_type?(right_type)
              right_type
            else
              :float
            end
          end
        end

        def vector_type?(type)
          %i[vec2 vec3 vec4].include?(type)
        end

        def matrix_type?(type)
          %i[mat2 mat3 mat4].include?(type)
        end

        def scalar_type?(type)
          %i[float int].include?(type)
        end

        def matrix_vector_result(matrix_type)
          case matrix_type
          when :mat2 then :vec2
          when :mat3 then :vec3
          when :mat4 then :vec4
          end
        end
      end
    end
  end
end
