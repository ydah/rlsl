# frozen_string_literal: true

module RLSL
  # C type definitions for the shader system
  C_TYPES = <<~C
    typedef struct { float x, y; } vec2;
    typedef struct { float x, y, z; } vec3;
    typedef struct { float x, y, z, w; } vec4;
    typedef struct { float m[4]; } mat2;
    typedef struct { float m[9]; } mat3;
    typedef struct { float m[16]; } mat4;
    typedef struct { void* data; int width; int height; } sampler2D;

    #define PI 3.14159265f
    #define TAU 6.28318530f
  C

  # Uniform type symbols
  UNIFORM_TYPES = %i[float vec2 vec3 vec4 int bool mat2 mat3 mat4 sampler2D].freeze

  # Type mapping helper
  module TypeMapping
    C_UNIFORM_TYPES = {
      float: "float",
      int: "int",
      bool: "int",
      vec2: "vec2",
      vec3: "vec3",
      vec4: "vec4",
      mat2: "mat2",
      mat3: "mat3",
      mat4: "mat4",
      sampler2D: "sampler2D"
    }.freeze
  end
end
