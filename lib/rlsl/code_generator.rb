# frozen_string_literal: true

module RLSL
  class CodeGenerator
    def initialize(name, uniforms, helpers_block, fragment_block)
      @name = name
      @uniforms = uniforms
      @helpers_block = helpers_block
      @fragment_block = fragment_block
    end

    def generate
      <<~C
        #include <ruby.h>
        #include <math.h>
        #include <stdint.h>
        #ifdef __APPLE__
        #include <dispatch/dispatch.h>
        #endif

        #{generate_types}
        #{generate_math_helpers}
        #{generate_uniform_struct}
        #{generate_custom_helpers}
        #{generate_shader_function}
        #{generate_ruby_wrapper}

        void Init_#{@name}(void) {
          VALUE mRLSL = rb_define_module("RLSL");
          VALUE mShaders = rb_define_module_under(mRLSL, "CompiledShaders");
          rb_define_module_function(mShaders, "#{@name}_render", shader_#{@name}_render, #{3 + @uniforms.size});
        }
      C
    end

    private

    def generate_types
      <<~C
        typedef struct { float x, y; } vec2;
        typedef struct { float x, y, z; } vec3;
        typedef struct { float x, y, z, w; } vec4;

        #define PI 3.14159265f
        #define TAU 6.28318530f
      C
    end

    def generate_math_helpers
      <<~C
        static inline vec2 vec2_new(float x, float y) { return (vec2){x, y}; }
        static inline vec3 vec3_new(float x, float y, float z) { return (vec3){x, y, z}; }
        static inline vec4 vec4_new(float x, float y, float z, float w) { return (vec4){x, y, z, w}; }

        static inline vec2 vec2_add(vec2 a, vec2 b) { return (vec2){a.x + b.x, a.y + b.y}; }
        static inline vec3 vec3_add(vec3 a, vec3 b) { return (vec3){a.x + b.x, a.y + b.y, a.z + b.z}; }

        static inline vec2 vec2_sub(vec2 a, vec2 b) { return (vec2){a.x - b.x, a.y - b.y}; }
        static inline vec3 vec3_sub(vec3 a, vec3 b) { return (vec3){a.x - b.x, a.y - b.y, a.z - b.z}; }

        static inline vec2 vec2_mul(vec2 a, float s) { return (vec2){a.x * s, a.y * s}; }
        static inline vec3 vec3_mul(vec3 a, float s) { return (vec3){a.x * s, a.y * s, a.z * s}; }

        static inline vec2 vec2_div(vec2 a, float s) { return (vec2){a.x / s, a.y / s}; }
        static inline vec3 vec3_div(vec3 a, float s) { return (vec3){a.x / s, a.y / s, a.z / s}; }

        static inline float vec2_dot(vec2 a, vec2 b) { return a.x * b.x + a.y * b.y; }
        static inline float vec3_dot(vec3 a, vec3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }

        static inline float vec2_length(vec2 v) { return sqrtf(v.x * v.x + v.y * v.y); }
        static inline float vec3_length(vec3 v) { return sqrtf(v.x * v.x + v.y * v.y + v.z * v.z); }

        static inline vec2 vec2_normalize(vec2 v) { float l = vec2_length(v); return l > 0 ? vec2_div(v, l) : v; }
        static inline vec3 vec3_normalize(vec3 v) { float l = vec3_length(v); return l > 0 ? vec3_div(v, l) : v; }

        static inline float fract(float x) { return x - floorf(x); }
        static inline float mix_f(float a, float b, float t) { return a + (b - a) * t; }
        static inline vec3 mix_v3(vec3 a, vec3 b, float t) {
          return (vec3){a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t};
        }

        static inline float clamp_f(float x, float lo, float hi) {
          return x < lo ? lo : (x > hi ? hi : x);
        }

        static inline float smoothstep(float edge0, float edge1, float x) {
          float t = clamp_f((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
          return t * t * (3.0f - 2.0f * t);
        }

        static inline float hash21(vec2 p) {
          float dot = p.x * 12.9898f + p.y * 78.233f;
          return fract(sinf(dot) * 43758.5453f);
        }

        static inline vec2 hash22(vec2 p) {
          float n = sinf(vec2_dot(p, vec2_new(127.1f, 311.7f)));
          return vec2_new(fract(n * 43758.5453f), fract(n * 12345.6789f));
        }

        // reflect: I - 2 * dot(N, I) * N
        static inline vec3 reflect(vec3 I, vec3 N) {
          float d = vec3_dot(N, I);
          return vec3_new(I.x - 2.0f * d * N.x, I.y - 2.0f * d * N.y, I.z - 2.0f * d * N.z);
        }

        // refract: Snell's law
        static inline vec3 refract(vec3 I, vec3 N, float eta) {
          float d = vec3_dot(N, I);
          float k = 1.0f - eta * eta * (1.0f - d * d);
          if (k < 0.0f) {
            return vec3_new(0.0f, 0.0f, 0.0f);  // Total internal reflection
          }
          float s = eta * d + sqrtf(k);
          return vec3_new(eta * I.x - s * N.x, eta * I.y - s * N.y, eta * I.z - s * N.z);
        }
      C
    end

    def generate_uniform_struct
      if @uniforms.empty?
        "typedef struct {} Uniforms;\n"
      else
        fields = @uniforms.map do |name, type|
          case type
          when :float then "  float #{name};"
          when :vec2 then "  vec2 #{name};"
          when :vec3 then "  vec3 #{name};"
          when :vec4 then "  vec4 #{name};"
          end
        end.join("\n")

        "typedef struct {\n#{fields}\n} Uniforms;\n"
      end
    end

    def generate_custom_helpers
      return "" unless @helpers_block

      @helpers_block.call
    end

    def generate_shader_function
      shader_body = @fragment_block.call

      <<~C
        static vec3 shader_#{@name}(vec2 frag_coord, vec2 resolution, Uniforms u) {
          #{shader_body}
        }
      C
    end

    def generate_ruby_wrapper
      uniform_args = @uniforms.map { |name, _| "VALUE rb_#{name}" }.join(", ")
      uniform_args = ", " + uniform_args unless uniform_args.empty?

      uniform_parsing = @uniforms.map do |name, type|
        case type
        when :float
          "  uniforms.#{name} = (float)NUM2DBL(rb_#{name});"
        when :vec2
          <<~C.strip
              Check_Type(rb_#{name}, T_ARRAY);
              uniforms.#{name} = vec2_new(
                (float)NUM2DBL(rb_ary_entry(rb_#{name}, 0)),
                (float)NUM2DBL(rb_ary_entry(rb_#{name}, 1))
              );
          C
        when :vec3
          <<~C.strip
              Check_Type(rb_#{name}, T_ARRAY);
              uniforms.#{name} = vec3_new(
                (float)NUM2DBL(rb_ary_entry(rb_#{name}, 0)),
                (float)NUM2DBL(rb_ary_entry(rb_#{name}, 1)),
                (float)NUM2DBL(rb_ary_entry(rb_#{name}, 2))
              );
          C
        end
      end.join("\n")

      <<~C
        static VALUE shader_#{@name}_render(VALUE self, VALUE rb_buffer, VALUE rb_width, VALUE rb_height#{uniform_args}) {
          int width = NUM2INT(rb_width);
          int height = NUM2INT(rb_height);
          vec2 resolution = vec2_new((float)width, (float)height);

          Uniforms uniforms;
          #{uniform_parsing}

          Check_Type(rb_buffer, T_STRING);
          rb_str_modify(rb_buffer);
          uint8_t *pixels = (uint8_t *)RSTRING_PTR(rb_buffer);

          #ifdef __APPLE__
          dispatch_apply(height, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t y) {
            int flipped_y = height - 1 - (int)y;
            for (int x = 0; x < width; x++) {
              vec2 frag_coord = vec2_new((float)x, (float)flipped_y);
              vec3 color = shader_#{@name}(frag_coord, resolution, uniforms);

              int idx = ((int)y * width + x) * 4;
              // Output as BGRA (macOS native format)
              pixels[idx] = (uint8_t)(clamp_f(color.z, 0.0f, 1.0f) * 255.0f);
              pixels[idx+1] = (uint8_t)(clamp_f(color.y, 0.0f, 1.0f) * 255.0f);
              pixels[idx+2] = (uint8_t)(clamp_f(color.x, 0.0f, 1.0f) * 255.0f);
              pixels[idx+3] = 255;
            }
          });
          #else
          for (int y = 0; y < height; y++) {
            int flipped_y = height - 1 - y;
            for (int x = 0; x < width; x++) {
              vec2 frag_coord = vec2_new((float)x, (float)flipped_y);
              vec3 color = shader_#{@name}(frag_coord, resolution, uniforms);

              int idx = (y * width + x) * 4;
              // Output as BGRA (macOS native format)
              pixels[idx] = (uint8_t)(clamp_f(color.z, 0.0f, 1.0f) * 255.0f);
              pixels[idx+1] = (uint8_t)(clamp_f(color.y, 0.0f, 1.0f) * 255.0f);
              pixels[idx+2] = (uint8_t)(clamp_f(color.x, 0.0f, 1.0f) * 255.0f);
              pixels[idx+3] = 255;
            }
          }
          #endif

          return Qnil;
        }
      C
    end
  end
end
