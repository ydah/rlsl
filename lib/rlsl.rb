# frozen_string_literal: true

require "fileutils"

require_relative "rlsl/version"
require_relative "rlsl/types"
require_relative "rlsl/uniform_context"
require_relative "rlsl/function_context"
require_relative "rlsl/code_generator"
require_relative "rlsl/compiled_shader"
require_relative "rlsl/base_translator"
require_relative "rlsl/msl/translator"
require_relative "rlsl/msl/shader"
require_relative "rlsl/wgsl/translator"
require_relative "rlsl/glsl/translator"
require_relative "rlsl/prism/transpiler"
require_relative "rlsl/shader_builder"

module RLSL
  CACHE_DIR = File.expand_path("~/.cache/rlsl/compiled")

  class << self
    def define(name, &block)
      builder = ShaderBuilder.new(name)
      builder.instance_eval(&block)
      builder.compile_and_load
    end

    def define_metal(name, &block)
      builder = ShaderBuilder.new(name)
      builder.instance_eval(&block)
      builder.build_metal_shader
    end

    def to_wgsl(name, &block)
      builder = ShaderBuilder.new(name)
      builder.instance_eval(&block)
      builder.build_wgsl_shader
    end

    def to_glsl(name, version: "450", &block)
      builder = ShaderBuilder.new(name)
      builder.instance_eval(&block)
      builder.build_glsl_shader(version: version)
    end

    def cache_dir
      @cache_dir ||= begin
        FileUtils.mkdir_p(CACHE_DIR)
        CACHE_DIR
      end
    end
  end

  module CompiledShaders
  end
end
