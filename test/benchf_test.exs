defmodule BenchfTest do
  use ExUnit.Case
  doctest Benchf

  test "greets the world" do
    assert Benchf.hello() == :world
  end
end
