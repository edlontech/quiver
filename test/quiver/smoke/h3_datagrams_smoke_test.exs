defmodule Quiver.Smoke.H3DatagramsSmokeTest do
  use Quiver.SmokeCase, async: false

  setup do
    name = :"smoke_dg_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         default: [
           protocol: :http3,
           verify: :verify_none,
           h3_settings: %{enable_connect_protocol: 1}
         ]
       }}
    )

    {:ok, name: name}
  end

  test "open_datagram_channel/4 round-trips 10 datagrams", %{name: name} do
    payloads =
      for i <- 1..10 do
        "dg-#{i}-#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
      end

    [first | _] = payloads

    handler = fn
      {:response, 200, _headers}, channel, acc ->
        :ok = Quiver.HTTP3.send_datagram(channel, first)
        {:cont, %{acc | response_seen: true}}

      {:response, status, _headers}, _channel, _acc ->
        {:halt, {:bad_status, status}}

      {:datagram, payload}, channel, %{remaining: [expected | rest], received: r} = acc
      when payload == expected ->
        case rest do
          [] ->
            {:halt, {:ok, %{acc | remaining: [], received: [payload | r]}}}

          [next | _] ->
            :ok = Quiver.HTTP3.send_datagram(channel, next)
            {:cont, %{acc | remaining: rest, received: [payload | r]}}
        end

      {:datagram, payload}, _channel, acc ->
        {:halt, {:unexpected_datagram, payload, acc}}

      {:closed, reason}, _channel, acc ->
        {:halt, {:closed, reason, acc}}

      _other, _channel, acc ->
        {:cont, acc}
    end

    initial = %{response_seen: false, remaining: payloads, received: []}

    assert {:ok, {:ok, final}} =
             Quiver.HTTP3.open_datagram_channel(
               h3_url("/datagrams/echo"),
               [method: :connect, protocol: "smoke-echo", name: name, receive_timeout: 10_000],
               handler,
               initial
             )

    assert final.response_seen == true
    assert final.remaining == []
    assert Enum.reverse(final.received) == payloads
  end
end
