# frozen_string_literal: true

require_relative "../test_helper"

class UniformContextTest < Test::Unit::TestCase
  test "initializes with empty uniforms" do
    ctx = RLSL::UniformContext.new
    assert_equal({}, ctx.uniforms)
  end

  test "float adds float uniform" do
    ctx = RLSL::UniformContext.new
    ctx.float(:time)
    assert_equal :float, ctx.uniforms[:time]
  end

  test "vec2 adds vec2 uniform" do
    ctx = RLSL::UniformContext.new
    ctx.vec2(:mouse)
    assert_equal :vec2, ctx.uniforms[:mouse]
  end

  test "vec3 adds vec3 uniform" do
    ctx = RLSL::UniformContext.new
    ctx.vec3(:camera)
    assert_equal :vec3, ctx.uniforms[:camera]
  end

  test "vec4 adds vec4 uniform" do
    ctx = RLSL::UniformContext.new
    ctx.vec4(:color)
    assert_equal :vec4, ctx.uniforms[:color]
  end
end
