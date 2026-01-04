# frozen_string_literal: true

begin
  require "metaco"
  METACO_AVAILABLE = true
rescue LoadError
  METACO_AVAILABLE = false
end

module RLSL
  module MSL
    class Shader
      attr_reader :name, :msl_source

      def initialize(name, uniforms, msl_source)
        @name = name
        @uniform_types = uniforms
        @uniform_names = uniforms.keys
        @msl_source = msl_source
        @compiled_handles = {}
      end

      def metal?
        true
      end

      def render_metal(handle, width, height, uniforms = {})
        unless METACO_AVAILABLE
          raise LoadError, "metaco gem is required for Metal rendering. Install it with: gem install metaco"
        end

        unless @compiled_handles[handle]
          Metaco.compile_compute_shader(handle, @msl_source)
          @compiled_handles[handle] = true
        end

        uniform_data = pack_uniforms(uniforms, width, height)

        Metaco.dispatch_compute(handle, uniform_data)
        Metaco.present_compute(handle)
      end

      private

      def pack_uniforms(uniforms, width, height)
        data = [width.to_f, height.to_f].pack("ff")
        current_offset = 8

        @uniform_names.each do |name|
          value = uniforms[name]
          type = @uniform_types[name]

          alignment = case type
                      when :float then 4
                      when :vec2 then 8
                      when :vec3, :vec4 then 16
                      end

          padding_needed = (alignment - (current_offset % alignment)) % alignment
          data += "\x00" * padding_needed
          current_offset += padding_needed

          case type
          when :float
            data += [value.to_f].pack("f")
            current_offset += 4
          when :vec2
            data += value.pack("ff")
            current_offset += 8
          when :vec3
            data += (value + [0.0]).pack("ffff")
            current_offset += 16
          when :vec4
            data += value.pack("ffff")
            current_offset += 16
          end
        end

        data.ljust(256, "\x00")
      end
    end
  end
end
