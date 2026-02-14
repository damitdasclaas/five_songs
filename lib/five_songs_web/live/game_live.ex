defmodule FiveSongsWeb.GameLive do
  use FiveSongsWeb, :live_view

  @default_play_duration_sec 60

  defp play_duration_sec do
    Application.get_env(:five_songs, :play_duration_sec, @default_play_duration_sec)
  end

  @impl true
  def mount(_params, session, socket) do
    token = session["spotify_access_token"]
    refresh_token = session["spotify_refresh_token"]

    socket =
      socket
      |> assign(:spotify_token, token)
      |> assign(:spotify_refresh_token, refresh_token)
      |> assign(:playlists, nil)
      |> assign(:playlists_error, nil)
      |> assign(:selected_playlist, nil)
      |> assign(:valid_tracks, [])
      |> assign(:tracks_loading, false)
      |> assign(:phase, nil)
      |> assign(:game_phase, :idle)
      |> assign(:current_track, nil)
      |> assign(:current_category, nil)
      |> assign(:reveal_data, nil)
      |> assign(:time_left_sec, nil)
      |> assign(:timer_ref, nil)
      |> assign(:refresh_timer_ref, nil)
      |> then(&compute_phase/1)

    socket =
      if socket.assigns.phase == :choose_playlist and token do
        send(self(), :load_playlists)
        schedule_token_refresh(socket)
      else
        socket
      end

    {:ok, socket}
  end

  defp compute_phase(socket) do
    phase =
      cond do
        is_nil(socket.assigns.spotify_token) -> :login
        is_nil(socket.assigns.selected_playlist) -> :choose_playlist
        true -> :game
      end

    assign(socket, :phase, phase)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="game-root" class="min-h-screen bg-zinc-900 text-white" phx-hook="SpotifyPlayer">
      <.flash_group flash={@flash} />
      <.login_screen :if={@phase == :login} />
      <.playlist_screen
        :if={@phase == :choose_playlist}
        playlists={@playlists}
        playlists_error={@playlists_error}
        tracks_loading={@tracks_loading}
        selected_playlist={@selected_playlist}
      />
      <.game_screen
        :if={@phase == :game}
        game_phase={@game_phase}
        current_category={@current_category}
        reveal_data={@reveal_data}
        time_left_sec={@time_left_sec}
        valid_tracks_count={length(@valid_tracks)}
      />
    </div>
    """
  end

  defp login_screen(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col items-center justify-center px-4">
      <h1 class="text-4xl font-bold tracking-tight">5songs</h1>
      <p class="mt-4 text-zinc-400">Mit Spotify anmelden, Playlist wählen, loslegen.</p>
      <a
        href={~p"/auth/spotify"}
        class="mt-8 inline-flex items-center gap-2 rounded-full bg-[#1DB954] px-6 py-3 font-semibold text-white transition hover:bg-[#1ed760]"
      >
        Mit Spotify anmelden
      </a>
    </div>
    """
  end

  defp playlist_screen(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col items-center justify-center px-4">
      <a href={~p"/auth/logout"} class="absolute right-4 top-4 text-sm text-zinc-400 hover:text-white">Abmelden</a>
      <h1 class="text-2xl font-bold">Playlist wählen</h1>
      <p :if={@playlists_error} class="mt-2 max-w-md text-center text-red-400">{@playlists_error}</p>
      <div :if={@playlists_error} class="mt-3 flex flex-wrap items-center justify-center gap-3 text-sm">
        <button
          phx-click="retry"
          class="rounded-lg bg-zinc-700 px-4 py-2 text-white hover:bg-zinc-600"
        >
          Nochmal versuchen
        </button>
        <a href={~p"/auth/spotify/reauth"} class="font-medium text-[#1DB954] underline hover:text-[#1ed760]">
          Erneut bei Spotify anmelden
        </a>
      </div>
      <div :if={@tracks_loading} class="mt-4 text-zinc-400">Lade Tracks…</div>
      <ul :if={@playlists && !@tracks_loading} class="mt-6 w-full max-w-md space-y-2">
        <li :for={playlist <- @playlists}>
          <button
            phx-click="select_playlist"
            phx-value-id={playlist.id}
            phx-value-name={playlist.name}
            class="w-full rounded-lg bg-zinc-800 px-4 py-3 text-left hover:bg-zinc-700"
          >
            {playlist.name}
          </button>
        </li>
      </ul>
      <p :if={@playlists == [] && !@playlists_error} class="mt-4 text-zinc-400">
        Keine Playlists gefunden.
      </p>
    </div>
    """
  end

  defp game_screen(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <a href={~p"/auth/logout"} class="absolute right-4 top-4 z-10 text-sm text-zinc-400 hover:text-white">Abmelden</a>
      <div
        :if={@game_phase == :playing && @current_category}
        class="flex flex-1 flex-col items-center justify-center transition-colors"
        style={"background-color: #{@current_category.color}"}
      >
        <p class="text-2xl font-semibold text-white/90">{@current_category.label}</p>
        <p :if={@time_left_sec != nil} class="mt-2 text-lg text-white/80">
          {@time_left_sec}s
        </p>
      </div>
      <div
        :if={@game_phase == :reveal && @reveal_data}
        class="flex flex-1 flex-col items-center justify-center bg-zinc-800 px-4"
      >
        <p class="text-4xl font-bold text-white">{@reveal_data.year}</p>
        <p class="mt-4 text-2xl font-semibold">{@reveal_data.title}</p>
        <p class="mt-2 text-xl text-zinc-400">{@reveal_data.artist}</p>
      </div>
      <div class="border-t border-zinc-700 p-4">
        <button
          :if={@game_phase == :idle || @game_phase == :reveal}
          phx-click="next_song"
          class="w-full rounded-lg bg-[#1DB954] py-3 font-semibold text-white hover:bg-[#1ed760] disabled:opacity-50"
          disabled={@valid_tracks_count == 0}
        >
          Nächster Song
        </button>
        <button
          :if={@game_phase == :playing}
          phx-click="stop_round"
          class="w-full rounded-lg bg-zinc-600 py-3 font-semibold text-white hover:bg-zinc-500"
        >
          Stopp / Reveal
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info(:load_playlists, socket) do
    token = socket.assigns.spotify_token

    with {:ok, me} <- Exspotify.Users.get_current_user_profile(token),
         {:ok, paging} <- Exspotify.Playlists.get_current_users_playlists(token, limit: 50) do
      all = paging.items || []
      playlists = Enum.filter(all, fn p -> p.owner && p.owner.id == me.id end)
      {:noreply, socket |> assign(:playlists, playlists) |> assign(:playlists_error, nil)}
    else
      {:error, %Exspotify.Error{type: :unauthorized}} ->
        {:noreply, redirect(socket, to: ~p"/auth/spotify/refresh")}
      _ ->
        {:noreply,
         assign(socket, :playlists_error, "Playlists konnten nicht geladen werden.")}
    end
  end

  def handle_info({:load_playlist_tracks, playlist_id}, socket) do
    token = socket.assigns.spotify_token

    case fetch_all_playlist_items(playlist_id, token) do
      {:ok, all_items} ->
        tracks =
          all_items
          |> Enum.map(&(Map.get(&1, "track") || Map.get(&1, :track)))
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(&(is_struct(&1, Exspotify.Structs.Track)))
          |> FiveSongs.Tracks.filter_valid()

        {:noreply,
         socket
         |> assign(:valid_tracks, tracks)
         |> assign(:playlists_error, nil)
         |> assign(:tracks_loading, false)
         |> cancel_refresh_timer()
         |> compute_phase()}

      {:error, %Exspotify.Error{type: :unauthorized}} ->
        {:noreply, redirect(socket, to: ~p"/auth/spotify/refresh")}

      {:error, reason} ->
        require Logger
        Logger.warning("Spotify get_playlist_items failed: #{inspect(reason)}")
        {:noreply,
         socket
         |> assign(:playlists_error, "Tracks konnten nicht geladen werden.")
         |> assign(:tracks_loading, false)}
    end
  end

  def handle_info(:time_up, socket) do
    socket = cancel_timer(socket)
    reveal_data = socket.assigns.current_track && FiveSongs.Tracks.reveal_data(socket.assigns.current_track)

    {:noreply,
     socket
     |> assign(:game_phase, :reveal)
     |> assign(:reveal_data, reveal_data)
     |> assign(:time_left_sec, nil)
     |> assign(:timer_ref, nil)
     |> push_event("pause_track", %{})}
  end

  def handle_info(:tick, socket) do
    left = socket.assigns.time_left_sec
    if left == nil or left <= 1 do
      send(self(), :time_up)
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:time_left_sec, left - 1)
       |> schedule_tick()}
    end
  end

  def handle_info(:refresh_token_redirect, socket) do
    if socket.assigns[:spotify_refresh_token] do
      {:noreply, redirect(socket, to: ~p"/auth/spotify/refresh")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_playlist", %{"id" => id, "name" => name}, socket) do
    socket =
      socket
      |> assign(:tracks_loading, true)
      |> assign(:playlists_error, nil)
      |> assign(:selected_playlist, %{id: id, name: name})

    send(self(), {:load_playlist_tracks, id})
    {:noreply, socket}
  end

  def handle_event("retry", _params, socket) do
    socket = assign(socket, :playlists_error, nil)
    if socket.assigns.selected_playlist do
      socket = assign(socket, :tracks_loading, true)
      send(self(), {:load_playlist_tracks, socket.assigns.selected_playlist.id})
    else
      send(self(), :load_playlists)
    end
    {:noreply, socket}
  end

  def handle_event("next_song", _params, socket) do
    valid_tracks = socket.assigns.valid_tracks
    if valid_tracks == [] do
      {:noreply, socket}
    else

    track = FiveSongs.Tracks.pick_random_track(valid_tracks)
    category = FiveSongs.Categories.pick_random()

    socket =
      socket
      |> assign(:current_track, track)
      |> assign(:current_category, category)
      |> assign(:reveal_data, nil)
      |> assign(:game_phase, :playing)
      |> assign(:time_left_sec, play_duration_sec())
      |> then(&start_play_timer/1)

    {:noreply, push_event(socket, "play_track", %{uri: track.uri, token: socket.assigns.spotify_token})}
    end
  end

  def handle_event("stop_round", _params, socket) do
    socket = cancel_timer(socket)
    reveal_data = socket.assigns.current_track && FiveSongs.Tracks.reveal_data(socket.assigns.current_track)

    {:noreply,
     socket
     |> assign(:game_phase, :reveal)
     |> assign(:reveal_data, reveal_data)
     |> assign(:time_left_sec, nil)
     |> push_event("pause_track", %{})}
  end

  defp start_play_timer(socket) do
    ref = Process.send_after(self(), :time_up, play_duration_sec() * 1000)
    socket
    |> assign(:timer_ref, ref)
    |> schedule_tick()
  end

  defp schedule_tick(socket) do
    if socket.assigns.game_phase == :playing do
      Process.send_after(self(), :tick, 1000)
    end
    socket
  end

  defp cancel_timer(socket) do
    if ref = socket.assigns.timer_ref do
      Process.cancel_timer(ref)
    end
    assign(socket, :timer_ref, nil)
  end

  # Token läuft nach ~1h ab; nach 45 min zur Refresh-Route schicken (nur auf Playlist-Bildschirm)
  defp schedule_token_refresh(socket) do
    if ref = socket.assigns[:refresh_timer_ref] do
      Process.cancel_timer(ref)
    end
    ref = Process.send_after(self(), :refresh_token_redirect, 45 * 60 * 1000)
    assign(socket, :refresh_timer_ref, ref)
  end

  defp cancel_refresh_timer(socket) do
    if ref = socket.assigns[:refresh_timer_ref] do
      Process.cancel_timer(ref)
    end
    assign(socket, :refresh_timer_ref, nil)
  end

  # Lädt alle Tracks einer Playlist (Pagination, max 500)
  defp fetch_all_playlist_items(playlist_id, token, max_items \\ 500) do
    limit = 50
    do_fetch_playlist_items(playlist_id, token, 0, limit, max_items, [])
  end

  defp do_fetch_playlist_items(playlist_id, token, offset, limit, max_items, acc) do
    case Exspotify.Playlists.get_playlist_items(playlist_id, token, limit: limit, offset: offset) do
      {:ok, paging} ->
        items = paging.items || []
        total = paging.total || 0
        acc = acc ++ items
        next_offset = offset + limit
        if next_offset >= total or next_offset >= max_items or items == [] do
          {:ok, acc}
        else
          do_fetch_playlist_items(playlist_id, token, next_offset, limit, max_items, acc)
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
end
