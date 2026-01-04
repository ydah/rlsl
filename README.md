# RLSL

Ruby Like Shading Language - A Ruby DSL for writing shaders that transpile to multiple GPU shader languages.

## Features

- Write shaders using Ruby syntax
- Transpile to multiple targets:
  - GLSL (OpenGL Shading Language)
  - WGSL (WebGPU Shading Language)
  - MSL (Metal Shading Language)
  - C (for CPU-based rendering)
- Type inference for shader variables
- Support for common shader operations (vec2, vec3, vec4, etc.)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rlsl'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install rlsl
```

## Usage

### Basic Example

```ruby
require 'rlsl'

# Generate GLSL shader
glsl_code = RLSL.to_glsl(:my_shader) do
  uniforms do
    float :time
  end

  fragment do |frag_coord, resolution, u|
    # Normalize coordinates
    uv = frag_coord / resolution

    # Create color based on position and time
    r = sin(u.time + uv.x * 6.28) * 0.5 + 0.5
    g = sin(u.time + uv.y * 6.28) * 0.5 + 0.5
    b = sin(u.time) * 0.5 + 0.5

    vec3(r, g, b)
  end
end

puts glsl_code
```

### Generate WGSL (WebGPU)

```ruby
wgsl_code = RLSL.to_wgsl(:my_shader) do
  uniforms do
    float :time
    vec2 :mouse
  end

  fragment do |frag_coord, resolution, u|
    uv = frag_coord / resolution.y
    color = vec3(uv.x, uv.y, sin(u.time) * 0.5 + 0.5)
    color
  end
end
```

### Generate MSL (Metal)

```ruby
metal_shader = RLSL.define_metal(:my_shader) do
  uniforms do
    float :time
  end

  fragment do |frag_coord, resolution, u|
    vec3(1.0, 0.0, 0.0)
  end
end
```

### Using Helper Functions

```ruby
RLSL.to_glsl(:complex_shader) do
  uniforms do
    float :time
  end

  functions do
    float :noise
    vec3 :get_color
  end

  helpers(:ruby) do
    def noise(p)
      sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453
    end

    def get_color(uv, t)
      vec3(uv.x, uv.y, sin(t) * 0.5 + 0.5)
    end
  end

  fragment do |frag_coord, resolution, u|
    uv = frag_coord / resolution
    get_color(uv, u.time)
  end
end
```

## Supported Types

- `bool` - Boolean (conditional logic)
- `int` - Integer (loop counters, array indices)
- `float` - Scalar floating point
- `vec2` - 2D vector
- `vec3` - 3D vector
- `vec4` - 4D vector
- `mat4` - 4x4 matrix (MVP transformations)
- `mat3` - 3x3 matrix (normal transformations)
- `mat2` - 2x2 matrix (2D texture coordinate transformations)
- `sampler2D` - 2D texture sampler

## Built-in Functions

RLSL supports common shader functions:

- Math: `sin`, `cos`, `tan`, `sqrt`, `pow`, `exp`, `log`, `abs`, `floor`, `ceil`
- Vector: `normalize`, `length`, `dot`, `cross`, `reflect`, `refract`
- Interpolation: `mix`, `clamp`, `smoothstep`
- Other: `fract`, `min`, `max`

## Constants

- `PI` - 3.14159265358979323846
- `TAU` - 6.28318530717958647692

## Requirements

- Ruby >= 3.1.0
- [Prism](https://github.com/ruby/prism) gem (for Ruby parsing)

### Optional: Metal Shader Execution (macOS only)

To run Metal shaders natively, install the [metaco](https://github.com/ydah/metaco) gem separately:

```bash
$ gem install metaco
```

Or add to your Gemfile:

```ruby
gem "metaco", platforms: :ruby, install_if: -> { RUBY_PLATFORM.include?("darwin") }
```

MSL code generation (`RLSL.define_metal`) works without metaco. The gem is only required when calling `render_metal` at runtime.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake test` to run the tests.

```bash
$ bundle install
$ rake test
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
