# frozen_string_literal: true

module RLSL
  module GLSL
    class Translator < BaseTranslator
      TYPE_MAP = {
        "vec2" => "vec2",
        "vec3" => "vec3",
        "vec4" => "vec4"
      }.freeze

      FUNC_REPLACEMENTS = BaseTranslator.common_func_replacements(
        target_vec2: "vec2",
        target_vec3: "vec3",
        target_vec4: "vec4"
      ).freeze

      def initialize(uniforms, helpers_code, fragment_code, version: "450")
        super(uniforms, helpers_code, fragment_code)
        @version = version
      end

      protected

      def translate_code(c_code)
        result = super(c_code)
        return result if result.empty?

        result.gsub!(/\bstatic\s+/, "")
        result.gsub!(/\binline\s+/, "")
        result
      end

      def generate_shader(helpers, fragment)
        <<~GLSL
          #version #{@version}

          // Uniforms
          #{generate_uniform_declarations}

          // Output
          layout(rgba8, binding = 0) uniform writeonly image2D outputImage;

          #{helpers}

          vec3 shader_fragment(vec2 frag_coord, vec2 resolution) {
              vec2 uv = frag_coord / resolution.y;
              #{fragment}
          }

          layout(local_size_x = 8, local_size_y = 8) in;
          void main() {
              ivec2 texSize = imageSize(outputImage);
              vec2 resolution = vec2(float(texSize.x), float(texSize.y));

              if (gl_GlobalInvocationID.x >= uint(resolution.x) ||
                  gl_GlobalInvocationID.y >= uint(resolution.y)) {
                  return;
              }

              vec2 frag_coord = vec2(float(gl_GlobalInvocationID.x),
                                     resolution.y - 1.0 - float(gl_GlobalInvocationID.y));
              vec3 color = shader_fragment(frag_coord, resolution);

              imageStore(outputImage, ivec2(gl_GlobalInvocationID.xy),
                         vec4(clamp(color, 0.0, 1.0), 1.0));
          }
        GLSL
      end

      private

      def generate_uniform_declarations
        declarations = ["layout(binding = 1) uniform ShaderUniforms {",
                        "    vec2 resolution;"]
        @uniforms.each do |name, type|
          glsl_type = uniform_type_to_target(type)
          declarations << "    #{glsl_type} #{name};"
        end
        declarations << "} u;"
        declarations.join("\n")
      end

      def target_vec2_type
        "vec2"
      end

      def target_vec3_type
        "vec3"
      end

      def target_vec4_type
        "vec4"
      end
    end
  end
end
