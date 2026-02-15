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
      selected_id = session["spotify_device_id"]
      {devices, loading} =
        case session["cached_devices"] do
          list when is_list(list) ->
            structs = Enum.map(list, &Exspotify.Structs.Device.from_map/1)
            {sort_devices(structs, selected_id), false}
          _ ->
            {nil, true}
        end

      socket =
        socket
        |> assign(:spotify_token, token)
        |> assign(:devices, devices)
        |> assign(:devices_loading, loading)
        |> assign(:devices_error, nil)
        |> assign(:selected_device_id, selected_id)
        |> assign(:play_duration_sec, session["play_duration_sec"] || @default_play_duration_sec)
        |> assign(:play_duration_options, @play_duration_options)

      if loading do
        {:ok, redirect(socket, to: ~p"/settings/refresh")}
      else
        {:ok, socket}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-900 text-white p-4 sm:p-6">
      <.flash_group flash={@flash} />
      <div class="mx-auto max-w-md space-y-8">
        <div class="flex items-center justify-between">
          <h1 class="text-xl font-bold">Einstellungen</h1>
          <a href={~p"/"} class="text-sm text-zinc-400 hover:text-white">← Zurück</a>
        </div>

        <section class="rounded-xl bg-zinc-800/60 p-4">
          <div class="mb-1 flex items-center justify-between gap-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-400">Abspielgerät</h2>
            <a
              href={~p"/settings/refresh"}
              class="shrink-0 rounded px-2 py-1 text-xs text-zinc-400 hover:bg-zinc-700 hover:text-white"
              title="Geräteliste neu laden"
            >
              Aktualisieren
            </a>
          </div>
          <p class="mb-3 text-sm text-zinc-500">
            Wähle, wo der Sound laufen soll.
          </p>
          <details class="mb-3 group">
            <summary class="cursor-pointer text-sm text-zinc-400 hover:text-zinc-300">Kein Ton auf dem Handy?</summary>
            <p class="mt-2 text-sm text-zinc-500">
              Wähle die <strong class="text-zinc-300">Spotify-App</strong> (z. B. „iPhone“) – dann läuft der Sound über die App.
            </p>
          </details>
          <div :if={@devices_error} class="mb-2 text-sm text-red-400">{@devices_error}</div>
          <div
            id="device-list"
            :if={@devices != nil && @devices != []}
            class="max-h-56 overflow-y-auto rounded-lg border border-zinc-700"
            phx-hook="ScrollSelectedDevice"
            data-selected-device-id={@selected_device_id}
          >
            <ul class="divide-y divide-zinc-700">
              <li
                :for={device <- @devices}
                data-device-id={device.id}
                class={"flex items-center gap-3 px-3 py-2 text-sm #{if device.id == @selected_device_id, do: "bg-[#1DB954]/20", else: "hover:bg-zinc-700/50"}"}
              >
                <span class="min-w-0 flex-1 truncate font-medium" title={device.name}>{device.name}</span>
                <span class="shrink-0 rounded bg-zinc-700 px-2 py-0.5 text-xs text-zinc-400">{device.type}</span>
                <a
                  href={~p"/settings/device?id=#{device.id}"}
                  class={"shrink-0 min-w-[4.5rem] rounded px-2 py-1 text-center text-xs font-medium transition #{if device.id == @selected_device_id, do: "bg-[#1DB954] text-white", else: "text-zinc-400 hover:bg-zinc-600 hover:text-white"}"}
                >
                  {if device.id == @selected_device_id, do: "Aktiv", else: "Wählen"}
                </a>
              </li>
            </ul>
          </div>
          <p :if={@devices != nil && @devices == []} class="mt-3 text-sm text-zinc-500">
            Keine Geräte gefunden. Starte Spotify auf einem Gerät.
          </p>
        </section>

        <section class="rounded-xl bg-zinc-800/60 p-4">
          <h2 class="mb-1 text-sm font-semibold uppercase tracking-wide text-zinc-400">Playlists</h2>
          <p class="text-sm text-zinc-500">
            Du kannst nur <strong class="text-zinc-300">eigene Playlists</strong> spielen.
            Um eine Playlist von jemand anderem zu nutzen, erstelle in Spotify eine neue Playlist
            und kopiere die Songs dorthin (alle markieren → in deine Playlist ziehen).
          </p>
        </section>

        <section class="rounded-xl bg-zinc-800/60 p-4">
          <h2 class="mb-1 text-sm font-semibold uppercase tracking-wide text-zinc-400">Spieldauer</h2>
          <p class="mb-3 text-sm text-zinc-500">Sekunden pro Song vor dem Raten.</p>
          <div class="flex flex-wrap gap-2">
            <a
              :for={sec <- @play_duration_options}
              href={~p"/settings/duration?sec=#{sec}"}
              class={"rounded-lg px-3 py-2 text-sm font-medium transition #{if sec == @play_duration_sec, do: "bg-[#1DB954] text-white", else: "bg-zinc-700 text-zinc-300 hover:bg-zinc-600"}"}
            >
              {sec}s
            </a>
          </div>
        </section>
      </div>
    </div>
    """
  end

  # Stabil sortieren: aktives Gerät zuerst, danach alphabetisch nach Name
  defp sort_devices(devices, selected_id) do
    Enum.sort_by(devices, fn d ->
      priority = if d.id == selected_id, do: 0, else: 1
      {priority, String.downcase(d.name || "")}
    end)
  end
end
