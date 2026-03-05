defmodule Quiver.Transport.SSLIntegrationTest do
  use ExUnit.Case, async: true
  @moduletag :integration

  alias Quiver.Transport.SSL

  describe "wildcard SAN matching" do
    test "connects to host with wildcard certificate (*.googleapis.com)" do
      assert {:ok, %SSL{}} =
               SSL.connect("generativelanguage.googleapis.com", 443,
                 alpn_advertised_protocols: ["h2"]
               )
    end
  end
end
