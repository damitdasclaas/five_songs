defmodule FiveSongsWeb.SettingsLive do
  use FiveSongsWeb, :live_view

  @play_duration_options [30, 45, 60, 75, 90]
  @default_play_duration_sec 60

  @impl true
  def mount(_params, session, socket) do
    token = session["spotify_access_token"]
    if is_nil(token) do
      {:ok, redirect(socket, to: ~p"/")}
    else
      socket =
        socket
        |> assign(:spotify_token, token)
        |> assign(:devices, nil)
        |> assign(:devices_loading, true)
        |> assign(:devices_error, nil)
        |> assign(:selected_device_id, session["spotify_device_id"])
        |> assign(:play_duration_sec, session["play_duration_sec"] || @default_play_duration_sec)
        |> assign(:play_duration_options, @play_duration_options)

      send(self(), :load_devices)
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-900 text-white p-6">
      <.flash_group flash={@flash} />
      <div class="mx-auto max-w-lg space-y-8">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Einstellungen</h1>
          <a href={~p"/"} class="text-sm text-zinc-400 hover:text-white">← Zurück</a>
        </div>

        <section>
          <h2 class="mb-2 text-sm font-medium text-zinc-400">Abspielgerät</h2>
          <p class="mb-4 text-sm text-zinc-500">
            Wähle das Gerät, auf dem die Songs abgespielt werden (z. B. Handy, Laptop, Lautsprecher).
          </p>
          <div :if={@devices_loading} class="text-zinc-400">Lade Geräte…</div>
          <div :if={@devices_error} class="text-red-400">{@devices_error}</div>
          <ul :if={@devices != nil && @devices != []} class="space-y-2">
            <li
              :for={device <- @devices}
              class={"flex items-center justify-between rounded-lg border p-3 #{if device.id == @selected_device_id, do: "border-[#1DB954] bg-zinc-800", else: "border-zinc-700 bg-zinc-800/50"}"}
            >
              <span class="font-medium">{device.name}</span>
              <span class="text-sm text-zinc-400">{device.type}</span>
              <a
                href={~p"/settings/device?id=#{device.id}"}
                class="rounded bg-[#1DB954] px-3 py-1.5 text-sm font-medium text-white hover:bg-[#1ed760]"
              >
                Wählen
              </a>
            </li>
          </ul>
          <p :if={@devices != nil && @devices == []} class="text-zinc-500">
            Keine Geräte gefunden. Starte Spotify auf einem Gerät oder öffne die Web-Player-Seite.
          </p>
        </section>

        <section>
          <h2 class="mb-2 text-sm font-medium text-zinc-400">Spieldauer pro Song (Sekunden)</h2>
          <p class="mb-4 text-sm text-zinc-500">Wie lange der Song abgespielt wird, bevor du raten kannst.</p>
          <div class="flex flex-wrap gap-2">
            <a
              :for={sec <- @play_duration_options}
              href={~p"/settings/duration?sec=#{sec}"}
              class={"rounded-lg px-4 py-2 text-sm font-medium transition #{if sec == @play_duration_sec, do: "bg-[#1DB954] text-white", else: "bg-zinc-700 text-zinc-300 hover:bg-zinc-600"}"}
            >
              {sec}s
            </a>
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info(:load_devices, socket) do
    token = socket.assigns.spotify_token

    case Exspotify.Player.get_available_devices(token) do
      {:ok, %{devices: devices}} ->
        {:noreply,
         socket
         |> assign(:devices, devices || [])
         |> assign(:devices_loading, false)
         |> assign(:devices_error, nil)}

      {:error, %Exspotify.Error{type: :unauthorized}} ->
        {:noreply, redirect(socket, to: ~p"/auth/spotify/reauth")}

      _ ->
        {:noreply,
         socket
         |> assign(:devices_loading, false)
         |> assign(:devices_error, "Geräte konnten nicht geladen werden.")}
    end
  end
end
