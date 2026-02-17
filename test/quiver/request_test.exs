defmodule Quiver.RequestTest do
  use ExUnit.Case, async: true

  alias Quiver.Request

  describe "struct creation" do
    test "creates request with required fields" do
      request = %Request{method: :get, url: URI.parse("https://example.com")}
      assert request.method == :get
      assert request.url == URI.parse("https://example.com")
      assert request.headers == []
      assert request.body == nil
    end

    test "creates request with all fields" do
      request = %Request{
        method: :post,
        url: URI.parse("https://example.com/api"),
        headers: [{"content-type", "application/json"}],
        body: ~s({"key": "value"})
      }

      assert request.method == :post
      assert request.headers == [{"content-type", "application/json"}]
      assert request.body == ~s({"key": "value"})
    end

    test "enforces method field" do
      assert_raise ArgumentError, fn ->
        struct!(Request, url: URI.parse("https://example.com"))
      end
    end

    test "enforces url field" do
      assert_raise ArgumentError, fn ->
        struct!(Request, method: :get)
      end
    end
  end
end
