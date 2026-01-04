# frozen_string_literal: true

require_relative "../test_helper"

class FunctionContextTest < Test::Unit::TestCase
  def setup
    @ctx = RLSL::FunctionContext.new
  end

  test "initializes with empty functions" do
    assert_equal({}, @ctx.functions)
  end

  test "float registers single function" do
    @ctx.float(:helper1)
    assert_equal({ returns: :float }, @ctx.functions[:helper1])
  end

  test "float registers multiple functions" do
    @ctx.float(:helper1, :helper2)
    assert_equal({ returns: :float }, @ctx.functions[:helper1])
    assert_equal({ returns: :float }, @ctx.functions[:helper2])
  end

  test "vec2 registers single function" do
    @ctx.vec2(:get_pos)
    assert_equal({ returns: :vec2 }, @ctx.functions[:get_pos])
  end

  test "vec2 registers multiple functions" do
    @ctx.vec2(:get_pos, :get_uv)
    assert_equal({ returns: :vec2 }, @ctx.functions[:get_pos])
    assert_equal({ returns: :vec2 }, @ctx.functions[:get_uv])
  end

  test "vec3 registers single function" do
    @ctx.vec3(:get_color)
    assert_equal({ returns: :vec3 }, @ctx.functions[:get_color])
  end

  test "vec3 registers multiple functions" do
    @ctx.vec3(:get_color, :get_normal)
    assert_equal({ returns: :vec3 }, @ctx.functions[:get_color])
    assert_equal({ returns: :vec3 }, @ctx.functions[:get_normal])
  end

  test "vec4 registers single function" do
    @ctx.vec4(:get_rgba)
    assert_equal({ returns: :vec4 }, @ctx.functions[:get_rgba])
  end

  test "vec4 registers multiple functions" do
    @ctx.vec4(:get_rgba, :get_clip_pos)
    assert_equal({ returns: :vec4 }, @ctx.functions[:get_rgba])
    assert_equal({ returns: :vec4 }, @ctx.functions[:get_clip_pos])
  end

  test "define registers function with return type only" do
    @ctx.define(:path_point, returns: :vec3)
    assert_equal({ returns: :vec3, params: {} }, @ctx.functions[:path_point])
  end

  test "define registers function with return type and params" do
    @ctx.define(:noise_a, returns: :float, params: { f: :float, h: :float })
    expected = { returns: :float, params: { f: :float, h: :float } }
    assert_equal(expected, @ctx.functions[:noise_a])
  end

  test "define registers complex function signature" do
    @ctx.define(:complex_func,
                returns: :vec3,
                params: { z: :float, p: :vec3, color: :vec4 })
    expected = {
      returns: :vec3,
      params: { z: :float, p: :vec3, color: :vec4 }
    }
    assert_equal(expected, @ctx.functions[:complex_func])
  end

  test "string name is converted to symbol" do
    @ctx.float("my_func")
    assert @ctx.functions.key?(:my_func)
  end

  test "multiple registrations can be combined" do
    @ctx.float(:f1)
    @ctx.vec2(:v2)
    @ctx.vec3(:v3)
    @ctx.vec4(:v4)
    @ctx.define(:custom, returns: :float, params: { x: :float })

    assert_equal 5, @ctx.functions.size
  end
end
