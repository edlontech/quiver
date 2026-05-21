defmodule Quiver.SmokeCase do
  @moduledoc """
  ExUnit case template for HTTP/3 docker smoke tests.

  Tags `:smoke` on the using module. At module load time, attempts a
  real QUIC handshake against UDP/4435 with a 1.5 s timeout. On failure
  the module is tagged `skip: msg` so ExUnit skips its tests with a
  clear message locally, or `SMOKE_REQUIRE=1` (used by CI) flips that
  into a hard failure via `setup_all`.
  """
  use ExUnit.CaseTemplate

  @h3_port 4435
  @probe_timeout_ms 1_500
  @probe_key {__MODULE__, :probe_result}

  using do
    case Quiver.SmokeCase.maybe_probe() do
      :ok ->
        quote do
          @moduletag :smoke
          import Quiver.SmokeCase,
            only: [h3_url: 1, h3_url: 2, h3_port: 0, get_header: 2, get_trailer: 2]
        end

      {:error, reason} ->
        msg =
          "h3-server on udp/#{Quiver.SmokeCase.h3_port()} unreachable (#{inspect(reason)}). " <>
            "Run `mix smoke.certs && mix smoke.up` first."

        require_smoke? = System.get_env("SMOKE_REQUIRE") == "1"

        quote do
          @moduletag :smoke
          import Quiver.SmokeCase,
            only: [h3_url: 1, h3_url: 2, h3_port: 0, get_header: 2, get_trailer: 2]

          if unquote(require_smoke?) do
            setup_all do
              flunk(unquote(msg))
            end
          else
            @moduletag skip: unquote(msg)
          end
        end
    end
  end

  def h3_port, do: @h3_port
  def h3_url(path, port \\ @h3_port), do: "https://localhost:#{port}#{path}"

  @doc """
  Case-insensitive header lookup on a list of `{name, value}` tuples.
  Returns the value or `nil`. Used by smoke tests asserting on response headers.
  """
  @spec get_header(list({String.t(), String.t()}), String.t()) :: String.t() | nil
  def get_header(headers, name) when is_list(headers) do
    lname = String.downcase(name)
    Enum.find_value(headers, fn {n, v} -> if String.downcase(n) == lname, do: v end)
  end

  @doc """
  Case-insensitive trailer lookup on a response struct. `resp.trailers` is a
  `[{name, value}]` list in Quiver's HTTP/3 stack.
  """
  @spec get_trailer(struct(), String.t()) :: String.t() | nil
  def get_trailer(%{trailers: trailers}, name), do: get_header(trailers, name)

  @doc false
  # Memoize via :persistent_term so N smoke modules compiled in one VM only pay
  # the 1.5 s handshake cost once. Concurrent compile may double-probe; acceptable.
  def maybe_probe do
    case :persistent_term.get(@probe_key, :unset) do
      :unset ->
        result = do_probe()
        :persistent_term.put(@probe_key, result)
        result

      cached ->
        cached
    end
  end

  defp do_probe do
    opts = %{verify: :verify_none, sync: true, connect_timeout: @probe_timeout_ms}

    case :quic_h3.connect(~c"localhost", @h3_port, opts) do
      {:ok, conn} ->
        _ = :quic_h3.close(conn)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
