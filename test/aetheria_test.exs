defmodule AetheriaTest do
  use ExUnit.Case
  doctest Aetheria

  test "greets the world" do
    assert Aetheria.hello() == :world
  end
end
