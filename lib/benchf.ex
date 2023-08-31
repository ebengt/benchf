defmodule Benchf do
  @moduledoc """
  Documentation for `Benchf`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Benchf.hello()
      :world

  """
  def hello do
    :world
  end

  def main([]) do
    IO.puts("#{:escript.script_name()} host port amount tasks [Nchf requests]")
    IO.puts("Request content is from Nchf example (unusable) and always the same.")
    IO.puts("Update/release use the identities from create.")

    IO.puts(
      "Create always replace session identities (create create, and the first identities are lost)."
    )

    IO.puts(
      "Example:\n #{:escript.script_name()} localhost 4000 1 1 create update update release"
    )
  end

  def main([host, port, amount, tasks | session_requests]) do
    host = Kernel.to_charlist(host)
    port = String.to_integer(port)
    amount = String.to_integer(amount)
    tasks = String.to_integer(tasks)

    IO.inspect(
      nchf_tasks(amount, tasks, host, port, :ercdf_test.sample_nchf_json(), session_requests)
    )
  end

  #
  # Internal functions
  #

  defp nchf_tasks(amount, tasks, host, port, json, session_requests) when amount > 0 do
    each_nchf = Kernel.div(amount, tasks)
    f = fn -> nchf_tc(each_nchf, host, port, json, session_requests) end
    awaits = for _ <- 1..tasks, do: Task.async(f)
    [slowest | _] = Task.await_many(awaits, each_nchf * 10000) |> Enum.sort(:desc)
    {each_nchf * tasks, slowest}
  end

  defp nchf_tc(amount, host, port, json, session_requests) do
    {:ok, pid} = :gun.open(host, port, %{protocols: [:http2]})
    {:ok, :http2} = :gun.await_up(pid)
    path = "/nchf-offlineonlycharging/v1/offlinechargingdata"
    header = %{"content-type" => "application/json"}

    result =
      :timer.tc(fn -> nchf_loop(session_requests, amount, [], {pid, path, header, json}) end)

    :gun.shutdown(pid)
    result
  end

  defp nchf_loop([], _amount, _, _), do: :ok

  defp nchf_loop(["create" | t], amount, _, http),
    do: nchf_loop_create(amount, {t, amount}, [], http)

  defp nchf_loop(["update" | t], amount, session_ids, http),
    do: nchf_loop_request(amount, session_ids, "update", {t, amount, session_ids}, http)

  defp nchf_loop(["release" | t], amount, session_ids, http),
    do: nchf_loop_request(amount, session_ids, "release", {t, amount, session_ids}, http)

  defp nchf_loop_create(0, {session_requests, amount}, session_ids, http),
    do: nchf_loop(session_requests, amount, session_ids, http)

  defp nchf_loop_create(n, loop, session_ids, {pid, path, header, json} = http) do
    body =
      json
      |> Map.put("invocationSequenceNumber", n)
      |> Map.put("invocationTimestamp", system_time())
      |> Jason.encode!()

    stream = :gun.post(pid, path, header, body)
    {:response, :nofin, 201, headers} = :gun.await(pid, stream)
    {:ok, _body} = :gun.await_body(pid, stream)
    {_location, location} = List.keyfind(headers, "location", 0)
    [_http, rest] = String.split(location, path)
    "/" <> session_id = rest
    nchf_loop_create(n - 1, loop, [session_id | session_ids], http)
  end

  defp nchf_loop_request(_n, [], _request, {session_requests, amount, session_ids}, http),
    do: nchf_loop(session_requests, amount, session_ids, http)

  defp nchf_loop_request(n, [session_id | t], request, loop, {pid, path, header, json} = http) do
    body =
      json
      |> Map.put("invocationSequenceNumber", n)
      |> Map.put("invocationTimestamp", system_time())
      |> :jsx.encode()

    stream = :gun.post(pid, path <> "/" <> session_id <> "/" <> request, header, body)
    {:response, :nofin, 200, _headers} = :gun.await(pid, stream)
    {:ok, _body} = :gun.await_body(pid, stream)
    nchf_loop_request(n + 1, t, request, loop, http)
  end

  defp system_time(), do: :os.system_time(:second)
end
