defmodule Quiver.Test.Certs do
  @moduledoc false

  @san_oid {2, 5, 29, 17}
  @rsa_key {:rsa, 2048, 65_537}

  def generate(hostname \\ "localhost") do
    san_extension = {:Extension, @san_oid, false, [{:dNSName, to_charlist(hostname)}]}

    result =
      :public_key.pkix_test_data(%{
        server_chain: %{
          root: [{:key, @rsa_key}],
          intermediates: [],
          peer: [{:key, @rsa_key}, {:extensions, [san_extension]}]
        },
        client_chain: %{
          root: [],
          intermediates: [],
          peer: []
        }
      })

    server = result.server_config

    %{
      cert: server[:cert],
      key: server[:key],
      cacerts: server[:cacerts],
      hostname: hostname
    }
  end
end
