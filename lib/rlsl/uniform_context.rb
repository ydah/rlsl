# frozen_string_literal: true

module RLSL
  # DSL context for defining uniform variables
  class UniformContext
    attr_reader :uniforms

    def initialize
      @uniforms = {}
    end

    def float(name)
      @uniforms[name] = :float
    end

    def vec2(name)
      @uniforms[name] = :vec2
    end

    def vec3(name)
      @uniforms[name] = :vec3
    end

    def vec4(name)
      @uniforms[name] = :vec4
    end
  end
end
