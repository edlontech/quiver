defmodule Quiver.ResponseTest do
  use ExUnit.Case, async: true

  alias Quiver.Response

  describe "struct creation" do
    test "creates response with required fields" do
      response = %Response{status: 200}
      assert response.status == 200
      assert response.headers == []
      assert response.body == nil
    end

    test "creates response with all fields" do
      response = %Response{
        status: 200,
        headers: [{"content-type", "text/html"}],
        body: "<html></html>"
      }

      assert response.status == 200
      assert response.headers == [{"content-type", "text/html"}]
      assert response.body == "<html></html>"
    end

    test "enforces status field" do
      assert_raise ArgumentError, fn ->
        struct!(Response, [])
      end
    end
  end
end
