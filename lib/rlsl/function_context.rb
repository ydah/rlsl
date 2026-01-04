# frozen_string_literal: true

module RLSL
  class FunctionContext
    attr_reader :functions

    def initialize
      @functions = {}
    end

    def float(*names)
      names.each { |name| @functions[name.to_sym] = { returns: :float } }
    end

    def vec2(*names)
      names.each { |name| @functions[name.to_sym] = { returns: :vec2 } }
    end

    def vec3(*names)
      names.each { |name| @functions[name.to_sym] = { returns: :vec3 } }
    end

    def vec4(*names)
      names.each { |name| @functions[name.to_sym] = { returns: :vec4 } }
    end

    # Full form: specify return type and parameter types
    # @example
    #   define :path_point, returns: :vec3, params: { z: :float }
    #   define :noise_a, returns: :float, params: { f: :float, h: :float, k: :float, p: :vec3 }
    def define(name, returns:, params: {})
      @functions[name.to_sym] = { returns: returns, params: params }
    end
  end
end
