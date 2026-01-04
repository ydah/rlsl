# frozen_string_literal: true

module RLSL
  class CompiledShader
    def initialize(name, ext_name, uniform_names)
      @name = name
      @ext_name = ext_name
      @uniform_names = uniform_names
      @render_method = RLSL::CompiledShaders.method("#{name}_render")
    end

    def metal?
      false
    end

    def render(buffer, width, height, uniforms = {})
      args = [buffer, width, height]
      @uniform_names.each do |name|
        args << uniforms[name]
      end
      @render_method.call(*args)
    end
  end
end
