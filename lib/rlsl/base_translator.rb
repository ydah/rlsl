# frozen_string_literal: true

module RLSL
  class BaseTranslator
    FUNC_REPLACEMENTS = [].freeze

    TYPE_MAP = {}.freeze

    def initialize(uniforms, helpers_code, fragment_code)
      @uniforms = uniforms
      @helpers_code = helpers_code || ""
      @fragment_code = fragment_code || ""
    end

    def translate
      helpers_translated = translate_code(@helpers_code)
      fragment_translated = translate_code(@fragment_code)
      generate_shader(helpers_translated, fragment_translated)
    end

    protected

    def translate_code(c_code)
      return "" if c_code.nil? || c_code.empty?

      result = c_code.dup

      self.class::TYPE_MAP.each do |c_type, target_type|
        result.gsub!(/\b#{c_type}\b/, target_type)
      end

      self.class::FUNC_REPLACEMENTS.each do |pattern, replacement|
        result.gsub!(pattern, replacement)
      end

      result
    end

    def generate_shader(_helpers, _fragment)
      raise NotImplementedError, "Subclasses must implement generate_shader"
    end

    def self.common_func_replacements(target_vec2:, target_vec3:, target_vec4:)
      [
        [/vec2_new\(([^,]+),\s*([^)]+)\)/, "#{target_vec2}(\\1, \\2)"],
        [/vec3_new\(([^,]+),\s*([^,]+),\s*([^)]+)\)/, "#{target_vec3}(\\1, \\2, \\3)"],
        [/vec4_new\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\)/, "#{target_vec4}(\\1, \\2, \\3, \\4)"],
        [/vec2_add\(([^,]+),\s*([^)]+)\)/, '(\1 + \2)'],
        [/vec3_add\(([^,]+),\s*([^)]+)\)/, '(\1 + \2)'],
        [/vec2_sub\(([^,]+),\s*([^)]+)\)/, '(\1 - \2)'],
        [/vec3_sub\(([^,]+),\s*([^)]+)\)/, '(\1 - \2)'],
        [/vec2_mul\(([^,]+),\s*([^)]+)\)/, '(\1 * \2)'],
        [/vec3_mul\(([^,]+),\s*([^)]+)\)/, '(\1 * \2)'],
        [/vec2_div\(([^,]+),\s*([^)]+)\)/, '(\1 / \2)'],
        [/vec3_div\(([^,]+),\s*([^)]+)\)/, '(\1 / \2)'],
        [/vec2_dot\(([^,]+),\s*([^)]+)\)/, 'dot(\1, \2)'],
        [/vec3_dot\(([^,]+),\s*([^)]+)\)/, 'dot(\1, \2)'],
        [/vec2_length\(([^)]+)\)/, 'length(\1)'],
        [/vec3_length\(([^)]+)\)/, 'length(\1)'],
        [/vec2_normalize\(([^)]+)\)/, 'normalize(\1)'],
        [/vec3_normalize\(([^)]+)\)/, 'normalize(\1)'],
        [/sqrtf\(/, "sqrt("],
        [/sinf\(/, "sin("],
        [/cosf\(/, "cos("],
        [/tanf\(/, "tan("],
        [/fabsf\(/, "abs("],
        [/fminf\(/, "min("],
        [/fmaxf\(/, "max("],
        [/floorf\(/, "floor("],
        [/ceilf\(/, "ceil("],
        [/powf\(/, "pow("],
        [/expf\(/, "exp("],
        [/logf\(/, "log("],
        [/atan2f\(/, "atan2("],
        [/fmodf\(/, "fmod("],
        [/mix_f\(/, "mix("],
        [/mix_v3\(/, "mix("],
        [/clamp_f\(/, "clamp("],
        [/smoothstep\(/, "smoothstep("],
        [/fract\(/, "fract("]
      ]
    end

    def uniform_type_to_target(type)
      case type
      when :float then target_float_type
      when :vec2 then target_vec2_type
      when :vec3 then target_vec3_type
      when :vec4 then target_vec4_type
      end
    end

    def target_float_type
      "float"
    end

    def target_vec2_type
      raise NotImplementedError
    end

    def target_vec3_type
      raise NotImplementedError
    end

    def target_vec4_type
      raise NotImplementedError
    end
  end
end
