# frozen_string_literal: true

require "prism"

require_relative "ir/nodes"
require_relative "source_extractor"
require_relative "builtins"
require_relative "ast_visitor"
require_relative "type_inference"
require_relative "emitters/base_emitter"
require_relative "emitters/c_emitter"
require_relative "emitters/msl_emitter"
require_relative "emitters/wgsl_emitter"
require_relative "emitters/glsl_emitter"

module RLSL
  module Prism
    class Transpiler
      TARGETS = {
        c: Emitters::CEmitter,
        msl: Emitters::MSLEmitter,
        wgsl: Emitters::WGSLEmitter,
        glsl: Emitters::GLSLEmitter
      }.freeze

      attr_reader :ir, :uniforms, :custom_functions

      def initialize(uniforms = {}, custom_functions = {})
        @uniforms = uniforms
        @custom_functions = custom_functions
        @source_extractor = SourceExtractor.new
        @ir = nil
      end

      def parse_block(block)
        source = @source_extractor.extract(block)
        parse_source(source)
      end

      def parse_source(source)
        params, body = extract_block_body(source)

        visitor = ASTVisitor.new(uniforms: @uniforms, params: params)
        @ir = visitor.parse(body)

        inference = TypeInference.new(@uniforms, @custom_functions)
        inference.register(:frag_coord, :vec2)
        inference.register(:resolution, :vec2)
        inference.infer(@ir)

        @ir
      end

      def emit(target, needs_return: true)
        raise "No IR parsed yet. Call parse_block or parse_source first." unless @ir

        emitter_class = TARGETS[target.to_sym]
        raise "Unknown target: #{target}" unless emitter_class

        emitter = emitter_class.new
        emitter.emit(@ir, needs_return: needs_return)
      end

      def transpile(block, target)
        parse_block(block)
        emit(target)
      end

      def transpile_source(source, target)
        parse_source(source)
        emit(target)
      end

      def transpile_helpers(block, target, function_signatures = {})
        source = @source_extractor.extract(block)
        _, body = extract_block_body(source)

        visitor = ASTVisitor.new(uniforms: @uniforms)
        @ir = visitor.parse(body)

        apply_function_signatures(@ir, function_signatures)

        inference = TypeInference.new(@uniforms, @custom_functions)
        inference.infer(@ir)

        emit(target, needs_return: false)
      end

      private

      def apply_function_signatures(ir, signatures)
        return unless ir.is_a?(IR::Block)

        ir.statements.each do |stmt|
          next unless stmt.is_a?(IR::FunctionDefinition)

          sig = signatures[stmt.name]
          next unless sig

          stmt.return_type = sig[:returns]
          stmt.param_types = sig[:params] || {}
        end
      end

      def extract_block_body(source)
        lines = source.strip.lines
        params = []

        first_line = lines.first&.strip || ""

        if first_line.start_with?("|")
          param_end = first_line.index("|", 1)
          if param_end
            param_str = first_line[1...param_end]
            params = param_str.split(",").map { |p| p.strip.to_sym }
            lines[0] = first_line[(param_end + 1)..]
          end
        end

        lines.shift while lines.first&.strip&.empty?
        lines.pop while lines.last&.strip&.empty?

        body = lines.join.strip
        [params, body]
      end
    end
  end
end
