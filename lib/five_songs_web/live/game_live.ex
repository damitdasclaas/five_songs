defmodule FiveSongsWeb.GameLive do
  use FiveSongsWeb, :live_view

  @play_duration_options [30, 45, 60, 75, 90]
  @default_play_duration_sec 60
  @max_auto_retry_sec 300

  @impl true
  def mount(_params, session, socket) do
    token = session["spotify_access_token"]
    refresh_token = session["spotify_refresh_token"]

    play_duration_sec =
      session["play_duration_sec"] ||
        Application.get_env(:five_songs, :play_duration_sec, @default_play_duration_sec)
    play_duration_sec = if play_duration_sec in @play_duration_options, do: play_duration_sec, else: @default_play_duration_sec

    socket =
      socket
      |> assign(:spotify_token, token)
      |> assign(:spotify_refresh_token, refresh_token)
      |> assign(:spotify_device_id, session["spotify_device_id"])
      |> assign(:playlists, nil)
      |> assign(:playlists_loading, false)
      |> assign(:playlists_error, nil)
      |> assign(:selected_playlist, nil)
      |> assign(:valid_tracks, [])
      |> assign(:tracks_cache, %{})
      |> assign(:played_track_ids, [])
      |> assign(:rate_limit_retry_ref, nil)
      |> assign(:rate_limit_blocked_until, nil)
      |> assign(:tracks_loading, false)
      |> assign(:show_start_menu, true)
      |> assign(:running_game, nil)
      |> assign(:phase, nil)
      |> assign(:game_started, false)
      |> assign(:year_range, nil)
      |> assign(:game_phase, :idle)
      |> assign(:current_track, nil)
      |> assign(:current_category, nil)
      |> assign(:reveal_data, nil)
      |> assign(:time_left_sec, nil)
      |> assign(:timer_ref, nil)
      |> assign(:refresh_timer_ref, nil)
      |> assign(:play_duration_sec, play_duration_sec)
      |> assign(:countdown_sec, nil)
      |> assign(:show_reveal, false)
      |> assign(:playback_started_timeout_ref, nil)
      |> then(&compute_phase/1)

    socket =
      if socket.assigns.phase == :choose_playlist and token do
        schedule_token_refresh(socket) |> push_event("check_running_game", %{})
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
        not socket.assigns.game_started -> :playlist_detail
        true -> :game
      end

    assign(socket, :phase, phase)
  end

  defp available_tracks_count(valid_tracks, played_ids) do
    played_set = MapSet.new(played_ids || [])
    Enum.count(valid_tracks || [], fn t -> t.id not in played_set end)
  end

  # Von API (Playlist-Struct): tracks.total
  defp playlist_track_count(%{tracks: t}) when is_map(t) do
    case t["total"] || Map.get(t, :total) do
      n when is_integer(n) -> n
      n when is_binary(n) -> case Integer.parse(n) do
        {val, _} -> val
        :error -> nil
      end
      _ -> nil
    end
  end
  # Aus Cache (nach restore_playlists)
  defp playlist_track_count(%{track_count: c}) when is_integer(c), do: c
  defp playlist_track_count(%{"track_count" => c}) when is_integer(c), do: c
  defp playlist_track_count(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div id="game-root" class="min-h-screen bg-gradient-to-b from-zinc-900 to-zinc-800/90 text-white" phx-hook="SpotifyPlayer" data-phase={@phase}>
      <.flash_group flash={@flash} />
      <.login_screen :if={@phase == :login} />
      <.start_menu_screen
        :if={@phase == :choose_playlist && @show_start_menu}
        running_game={@running_game}
      />
      <.playlist_screen
        :if={@phase == :choose_playlist && !@show_start_menu}
        playlists={@playlists}
        playlists_loading={@playlists_loading}
        playlists_error={@playlists_error}
      />
      <.playlist_detail_screen
        :if={@phase == :playlist_detail}
        selected_playlist={@selected_playlist}
        tracks_loading={@tracks_loading}
        playlists_error={@playlists_error}
        total_count={length(@valid_tracks || [])}
        year_range={@year_range}
      />
      <.game_screen
        :if={@phase == :game}
        game_phase={@game_phase}
        current_category={@current_category}
        reveal_data={@reveal_data}
        show_reveal={@show_reveal}
        time_left_sec={@time_left_sec}
        valid_tracks_count={available_tracks_count(@valid_tracks, @played_track_ids)}
        played_count={length(@played_track_ids || [])}
        total_count={length(@valid_tracks || [])}
        countdown_sec={@countdown_sec}
        play_duration_sec={@play_duration_sec}
      />
    </div>
    """
  end

  defp login_screen(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-zinc-900 via-zinc-900 to-zinc-800/80 px-4">
      <img src="/images/5songs.svg" alt="5songs" class="h-28 w-auto drop-shadow-lg sm:h-32" />
      <p class="mt-6 text-zinc-400">Mit Spotify anmelden, Playlist wählen, loslegen.</p>
      <a
        href={~p"/auth/spotify"}
        class="mt-8 inline-flex items-center gap-2 rounded-full bg-[#1DB954] px-8 py-3.5 font-semibold text-white shadow-lg shadow-[#1DB954]/25 transition hover:bg-[#1ed760] hover:shadow-[#1ed760]/30 hover:scale-[1.02] active:scale-[0.98]"
      >
        Mit Spotify anmelden
      </a>
    </div>
    """
  end

  defp start_menu_screen(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-zinc-900 via-zinc-900 to-zinc-800/80 px-4">
      <div class="absolute right-4 top-4">
        <a href={~p"/auth/logout"} class="inline-flex items-center justify-center rounded-full bg-zinc-800/80 p-3 text-zinc-400 transition hover:bg-zinc-700 hover:text-white active:bg-zinc-600" title="Abmelden">
          <.icon name="hero-arrow-right-start-on-rectangle" class="h-6 w-6" />
        </a>
      </div>
      <img src="/images/5songs.svg" alt="5songs" class="h-28 w-auto drop-shadow-lg sm:h-32" />
      <p class="mt-4 text-zinc-400">Playlist wählen und Songs erraten.</p>
      <div class="mt-10 flex w-full max-w-xs flex-col gap-3">
        <button
          :if={@running_game}
          phx-click="continue_game"
          phx-value-id={@running_game.id}
          phx-value-name={@running_game.name}
          type="button"
          class="rounded-full bg-[#1DB954] px-8 py-4 text-lg font-semibold text-white shadow-lg shadow-[#1DB954]/25 transition hover:bg-[#1ed760] hover:shadow-[#1ed760]/30 hover:scale-[1.02] active:scale-[0.98]"
        >
          Weiterspielen
        </button>
        <button
          phx-click="show_playlists"
          type="button"
          class={[
            "rounded-full px-8 py-4 text-lg font-semibold transition",
            @running_game && "border border-zinc-600 bg-zinc-800/50 hover:bg-zinc-800 hover:border-zinc-500" ||
              "bg-[#1DB954] text-white shadow-lg shadow-[#1DB954]/25 hover:bg-[#1ed760] hover:shadow-[#1ed760]/30 hover:scale-[1.02] active:scale-[0.98]"
          ]}
        >
          {@running_game && "Neues Spiel" || "Spiel starten"}
        </button>
        <a
          href={~p"/settings"}
          class="rounded-full border border-zinc-600 bg-zinc-800/50 px-8 py-4 text-center text-lg font-semibold text-white transition hover:bg-zinc-800 hover:border-zinc-500"
        >
          Einstellungen
        </a>
      </div>
    </div>
    """
  end

  defp playlist_screen(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-zinc-900 via-zinc-900 to-zinc-800/80 px-4">
      <div class="absolute left-4 right-4 top-4 flex items-center justify-between">
        <button type="button" phx-click="back_to_start_menu" class="inline-flex items-center gap-1 rounded-full bg-zinc-800/80 px-3 py-2 text-sm text-zinc-300 transition hover:bg-zinc-700 active:bg-zinc-600">
          <.icon name="hero-chevron-left" class="h-4 w-4" /> Menü
        </button>
        <div class="flex items-center gap-2">
          <a href={~p"/settings"} class="inline-flex items-center justify-center rounded-full bg-zinc-800/80 p-3 text-zinc-400 transition hover:bg-zinc-700 hover:text-white active:bg-zinc-600" title="Einstellungen">
            <.icon name="hero-cog-6-tooth" class="h-6 w-6" />
          </a>
          <a href={~p"/auth/logout"} class="inline-flex items-center justify-center rounded-full bg-zinc-800/80 p-3 text-zinc-400 transition hover:bg-zinc-700 hover:text-white active:bg-zinc-600" title="Abmelden">
            <.icon name="hero-arrow-right-start-on-rectangle" class="h-6 w-6" />
          </a>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <h1 class="text-2xl font-bold">Playlist wählen</h1>
        <button
          :if={@playlists != nil}
          phx-click="load_playlists"
          disabled={@playlists_loading}
          class="rounded p-1.5 text-zinc-400 hover:bg-zinc-700 hover:text-white disabled:opacity-50"
          title="Playlists aktualisieren"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
        </button>
      </div>
      <div :if={@playlists == nil && !@playlists_error && !@playlists_loading} class="mt-6">
        <button
          phx-click="load_playlists"
          class="rounded-lg bg-[#1DB954] px-6 py-3 font-semibold text-white hover:bg-[#1ed760]"
        >
          Playlists laden
        </button>
      </div>
      <div :if={@playlists_loading} class="mt-6 text-zinc-400">Lade Playlists…</div>
      <p :if={@playlists_error} class="mt-2 max-w-md text-center text-red-400">{@playlists_error}</p>
      <div :if={@playlists_error} class="mt-3 flex flex-wrap items-center justify-center gap-3 text-sm">
        <button
          phx-click="load_playlists"
          class="rounded-lg bg-zinc-700 px-4 py-2 text-white hover:bg-zinc-600"
        >
          Nochmal versuchen
        </button>
        <a href={~p"/auth/spotify/reauth"} class="font-medium text-[#1DB954] underline hover:text-[#1ed760]">
          Erneut bei Spotify anmelden
        </a>
      </div>
      <div :if={@playlists && !@playlists_loading} class="mt-6 w-full max-w-md max-h-[60vh] overflow-y-auto rounded-2xl border border-zinc-600/80 bg-zinc-800/40 shadow-xl shadow-black/20">
        <ul class="divide-y divide-zinc-700">
          <li :for={playlist <- @playlists}>
            <button
              phx-click="select_playlist"
              phx-value-id={playlist.id}
              phx-value-name={playlist.name}
              class="w-full px-4 py-3 text-left hover:bg-zinc-700/50"
            >
              {playlist.name}
            </button>
          </li>
        </ul>
      </div>
      <p :if={@playlists == [] && !@playlists_error && !@playlists_loading} class="mt-4 text-zinc-400">
        Keine Playlists gefunden.
      </p>
    </div>
    """
  end

  defp playlist_detail_screen(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-zinc-900 via-zinc-900 to-zinc-800/80 px-4">
      <div class="absolute left-4 right-4 top-4 flex items-center justify-between">
        <button type="button" phx-click="back_to_playlists" class="inline-flex items-center gap-1 rounded-full bg-zinc-800/80 px-3 py-2 text-sm text-zinc-300 transition hover:bg-zinc-700 active:bg-zinc-600">
          <.icon name="hero-chevron-left" class="h-4 w-4" /> Playlists
        </button>
        <a href={~p"/auth/logout"} class="inline-flex items-center justify-center rounded-full bg-zinc-800/80 p-3 text-zinc-400 transition hover:bg-zinc-700 hover:text-white active:bg-zinc-600" title="Abmelden">
          <.icon name="hero-arrow-right-start-on-rectangle" class="h-6 w-6" />
        </a>
      </div>
      <h1 class="text-2xl font-bold">{@selected_playlist.name}</h1>
      <div :if={@tracks_loading} class="mt-4 text-zinc-400">Lade Tracks…</div>
      <%!-- Forbidden: Kein Zugriff auf fremde Playlist --%>
      <div :if={@playlists_error == :forbidden} class="mt-4 max-w-md space-y-3 text-center">
        <p class="text-red-400">Kein Zugriff auf diese Playlist.</p>
        <p class="text-sm text-zinc-500">
          Du kannst nur <strong class="text-zinc-300">eigene Playlists</strong> spielen.
          Um diese Playlist zu nutzen, erstelle in Spotify eine neue Playlist
          und kopiere die Songs dorthin (alle markieren → in deine Playlist ziehen).
        </p>
      </div>
      <%!-- Anderer Fehler --%>
      <p :if={@playlists_error && @playlists_error != :forbidden} class="mt-2 max-w-md text-center text-red-400">{@playlists_error}</p>
      <%!-- Erfolg: Track-Info --%>
      <div :if={!@tracks_loading && !@playlists_error && @total_count > 0} class="mt-4 text-center">
        <p class="text-lg text-zinc-300">{@total_count} Songs</p>
        <p :if={@year_range} class="text-zinc-500">{elem(@year_range, 0)}–{elem(@year_range, 1)}</p>
      </div>
      <div :if={!@tracks_loading} class="mt-8 flex w-full max-w-xs flex-col gap-3">
        <button
          :if={!@playlists_error && @total_count > 0}
          phx-click="start_playlist"
          class="rounded-full bg-[#1DB954] px-8 py-4 text-lg font-semibold text-white shadow-lg shadow-[#1DB954]/25 transition hover:bg-[#1ed760] hover:shadow-[#1ed760]/30 hover:scale-[1.02] active:scale-[0.98]"
        >
          Diese Playlist spielen
        </button>
        <button
          phx-click="back_to_playlists"
          class="rounded-full border border-zinc-600 bg-zinc-800/50 px-8 py-4 text-lg font-semibold text-white transition hover:bg-zinc-800 hover:border-zinc-500"
        >
          Andere Playlist wählen
        </button>
      </div>
    </div>
    """
  end

  defp game_screen(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <div class="absolute left-4 right-4 top-4 z-10 flex items-center justify-between">
        <button phx-click="back_to_playlists" type="button" class="inline-flex items-center gap-1 rounded-full bg-zinc-800/80 px-3 py-2 text-sm text-zinc-300 transition hover:bg-zinc-700 active:bg-zinc-600">
          <.icon name="hero-chevron-left" class="h-4 w-4" /> Zurück
        </button>
        <span class="rounded-full bg-zinc-800 px-3 py-1.5 text-sm font-medium tabular-nums text-zinc-300">{@played_count}/{@total_count}</span>
      </div>
      <%!-- Idle: Warten auf "Nächste Runde" --%>
      <div
        :if={@game_phase == :idle}
        class="flex flex-1 flex-col items-center justify-center bg-zinc-800 px-6"
      >
        <p class="text-xl text-zinc-400">Bereit für die nächste Runde?</p>
        <button
          phx-click="next_round"
          class="mt-8 w-full max-w-xs rounded-lg bg-[#1DB954] py-3 font-semibold text-white hover:bg-[#1ed760] disabled:opacity-50"
          disabled={@valid_tracks_count == 0}
        >
          Nächste Runde
        </button>
        <p :if={@valid_tracks_count == 0} class="mt-3 text-center text-sm text-amber-400">
          Alle {@total_count} Songs dieser Playlist wurden gespielt!
        </p>
      </div>
      <%!-- Kategorie ausgelost → "Song abspielen" --%>
      <div
        :if={@game_phase == :category_picked && @current_category}
        class="flex flex-1 flex-col items-center justify-center px-6 transition-colors"
        style={"background-color: #{@current_category.color}"}
      >
        <p class="text-3xl font-bold text-white">{@current_category.label}</p>
        <p class="mt-2 text-white/70">Kategorie dieser Runde</p>
        <button
          phx-click="play_song"
          class="mt-8 w-full max-w-xs rounded-lg bg-white/20 py-3 font-semibold text-white backdrop-blur hover:bg-white/30"
        >
          Song abspielen
        </button>
      </div>
      <%!-- Countdown --%>
      <div
        :if={@game_phase == :countdown && @countdown_sec != nil}
        class="flex flex-1 flex-col items-center justify-center"
        style={"background-color: #{@current_category && @current_category.color || "#27272a"}"}
      >
        <p class="text-sm font-medium text-white/70">{@current_category && @current_category.label}</p>
        <p class="mt-2 text-8xl font-bold tabular-nums text-white">{@countdown_sec}</p>
      </div>
      <%!-- Playing --%>
      <div
        :if={@game_phase == :playing && @current_category}
        class="relative flex flex-1 flex-col items-center justify-center overflow-hidden px-6 transition-colors"
        style={"background-color: #{@current_category.color}"}
      >
        <div
          :if={@time_left_sec != nil && @time_left_sec <= 10}
          class="pointer-events-none absolute inset-0"
          style={"border: 3px solid rgba(239, 68, 68, 0.95); box-shadow: inset 0 0 30px 10px rgba(239, 68, 68, 0.8), inset 0 0 80px 20px rgba(239, 68, 68, 0.25); animation: vignette-pulse #{vignette_pulse_speed(@time_left_sec)} ease-in-out infinite;"}
        />
        <p class="text-2xl font-semibold text-white/90">{@current_category.label}</p>
        <p :if={@time_left_sec != nil} class="mt-4 text-7xl font-bold tabular-nums text-white">
          {@time_left_sec}<span class="text-4xl">s</span>
        </p>
        <div :if={@time_left_sec != nil} class="mt-6 h-2 w-full max-w-xs overflow-hidden rounded-full bg-white/20">
          <div
            class={[
              "h-full rounded-full transition-[width] duration-1000 ease-linear",
              cond do
                @time_left_sec <= 5 -> "bg-red-400"
                @time_left_sec <= 15 -> "bg-amber-300"
                true -> "bg-white/80"
              end
            ]}
            style={"width: #{@time_left_sec / @play_duration_sec * 100}%"}
          />
        </div>
        <button
          phx-click="stop_round"
          class="mt-8 w-full max-w-xs rounded-lg bg-white/20 py-3 font-semibold text-white backdrop-blur hover:bg-white/30"
        >
          Stopp / Auflösen
        </button>
      </div>
      <%!-- Reveal: "Auflösen" --%>
      <div
        :if={@game_phase == :reveal && @reveal_data && !@show_reveal}
        class="flex flex-1 flex-col items-center justify-center px-6"
        style={"background-color: #{@current_category && @current_category.color || "#27272a"}"}
      >
        <p :if={@current_category} class="text-sm font-medium text-white/70">{@current_category.label}</p>
        <p class="mt-2 text-xl text-white/80">Runde vorbei.</p>
        <button
          phx-click="show_reveal"
          class="mt-8 w-full max-w-xs rounded-lg bg-[#1DB954] py-3 font-semibold text-white hover:bg-[#1ed760]"
        >
          Auflösen
        </button>
      </div>
      <%!-- Reveal: Ergebnis sichtbar --%>
      <div
        :if={@game_phase == :reveal && @reveal_data && @show_reveal}
        class="flex flex-1 flex-col items-center justify-center px-6"
        style={"background-color: #{@current_category && @current_category.color || "#27272a"}"}
      >
        <p :if={@current_category} class="mb-4 text-sm font-medium text-white/70">{@current_category.label}</p>
        <p class="text-5xl font-bold text-white">{@reveal_data.year}</p>
        <p class="mt-4 text-2xl font-semibold text-white">{@reveal_data.title}</p>
        <p class="mt-1 text-xl text-white/70">{@reveal_data.artist}</p>
        <img
          :if={@reveal_data[:cover_url]}
          src={@reveal_data.cover_url}
          alt="Album Cover"
          class="mt-5 h-20 w-20 rounded shadow-md"
        />
        <a
          :if={@reveal_data[:spotify_url]}
          href={@reveal_data.spotify_url}
          target="_blank"
          rel="noopener"
          class="mt-4 text-sm text-white/60 hover:text-white"
        >
          In Spotify öffnen ↗
        </a>
        <button
          phx-click="next_round"
          class="mt-8 w-full max-w-xs rounded-lg bg-white/20 py-3 font-semibold text-white backdrop-blur hover:bg-white/30 disabled:opacity-50"
          disabled={@valid_tracks_count == 0}
        >
          Nächste Runde
        </button>
        <p :if={@valid_tracks_count == 0} class="mt-3 text-center text-sm text-amber-200">
          Alle {@total_count} Songs dieser Playlist wurden gespielt!
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info(:load_playlists, socket) do
    token = socket.assigns.spotify_token

    result =
      with {:ok, paging} <- Exspotify.Playlists.get_current_users_playlists(token, limit: 50) do
        all = paging.items || []
        # Alle Playlists aus der Bibliothek (eigene + gefolgte/öffentliche)
        playlists =
          Enum.map(all, fn p ->
            %{id: p.id, name: p.name, track_count: playlist_track_count(p), snapshot_id: p.snapshot_id}
          end)

        cache =
          Enum.map(playlists, fn pm ->
            m = %{"id" => pm.id, "name" => pm.name}
            m = if is_integer(pm.track_count), do: Map.put(m, "track_count", pm.track_count), else: m
            if pm[:snapshot_id], do: Map.put(m, "snapshot_id", pm.snapshot_id), else: m
          end)

        {:noreply,
         socket
         |> assign(:playlists, playlists)
         |> assign(:playlists_loading, false)
         |> assign(:playlists_error, nil)
         |> push_event("cache_playlists", %{playlists: cache})}
      else
        {:error, %Exspotify.Error{type: :unauthorized}} ->
          {:noreply, redirect(socket, to: ~p"/auth/spotify/refresh")}
        {:error, %Exspotify.Error{type: :rate_limited, details: details}} ->
          {:noreply,
           socket
           |> assign(:playlists_loading, false)
           |> assign(:playlists_error, rate_limit_message(details))
           |> schedule_rate_limit_retry(:load_playlists, details)}
        _ ->
          {:noreply,
           socket
           |> assign(:playlists_loading, false)
           |> assign(:playlists_error, "Playlists konnten nicht geladen werden.")}
      end

    result
  end

  def handle_info({:load_playlist_tracks, playlist_id}, socket) do
    # snapshot_id-basierter Cache: Wenn die Playlist sich nicht geändert hat, Tracks wiederverwenden.
    # Spart 1-4 API-Requests pro Playlist-Auswahl (Spotify empfiehlt das explizit).
    cached = socket.assigns.tracks_cache[playlist_id]
    current_snapshot = get_playlist_snapshot(socket.assigns.playlists, playlist_id)

    if cached && current_snapshot && cached.snapshot_id == current_snapshot do
      # Cache-Hit → kein API-Call nötig
      {:noreply,
       socket
       |> assign(:valid_tracks, cached.tracks)
       |> assign(:year_range, cached[:year_range])
       |> assign(:playlists_error, nil)
       |> assign(:tracks_loading, false)
       |> cancel_refresh_timer()
       |> compute_phase()
       |> push_event("request_saved_state", %{playlist_id: playlist_id})}
    else
      # Cache-Miss oder snapshot_id geändert → von API laden
      token = socket.assigns.spotify_token

      case fetch_all_playlist_items(playlist_id, token) do
        {:ok, all_items} ->
          tracks =
            all_items
            |> Enum.map(&(Map.get(&1, "track") || Map.get(&1, :track)))
            |> Enum.reject(&is_nil/1)
            |> Enum.filter(&(is_struct(&1, Exspotify.Structs.Track)))
            |> FiveSongs.Tracks.filter_valid()

          year_range = compute_year_range(tracks)
          new_cache = Map.put(socket.assigns.tracks_cache, playlist_id, %{
            snapshot_id: current_snapshot,
            tracks: tracks,
            year_range: year_range
          })

          {:noreply,
           socket
           |> assign(:valid_tracks, tracks)
           |> assign(:year_range, year_range)
           |> assign(:tracks_cache, new_cache)
           |> assign(:playlists_error, nil)
           |> assign(:tracks_loading, false)
           |> cancel_refresh_timer()
           |> compute_phase()
           |> push_event("request_saved_state", %{playlist_id: playlist_id})}

        {:error, %Exspotify.Error{type: :unauthorized}} ->
          {:noreply, redirect(socket, to: ~p"/auth/spotify/refresh")}

        {:error, %Exspotify.Error{type: :forbidden}} ->
          {:noreply,
           socket
           |> assign(:playlists_error, :forbidden)
           |> assign(:tracks_loading, false)}

        {:error, %Exspotify.Error{type: :rate_limited, details: details}} ->
          {:noreply,
           socket
           |> assign(:playlists_error, rate_limit_message(details))
           |> assign(:tracks_loading, false)
           |> schedule_rate_limit_retry({:load_playlist_tracks, playlist_id}, details)}

        {:error, reason} ->
          require Logger
          Logger.warning("Spotify get_playlist_items failed: #{inspect(reason)}")
          {:noreply,
           socket
           |> assign(:playlists_error, "Tracks konnten nicht geladen werden.")
           |> assign(:tracks_loading, false)}
      end
    end
  end

  def handle_info(:time_up, socket) do
    socket = socket |> cancel_timer() |> cancel_playback_started_timeout()
    reveal_data = socket.assigns.current_track && FiveSongs.Tracks.reveal_data(socket.assigns.current_track)

    {:noreply,
     socket
     |> assign(:game_phase, :reveal)
     |> assign(:reveal_data, reveal_data)
     |> assign(:show_reveal, false)
     |> assign(:time_left_sec, nil)
     |> assign(:timer_ref, nil)
     |> push_event("pause_track", pause_payload(socket))}
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

  def handle_info(:playback_started_timeout, socket) do
    socket = cancel_playback_started_timeout(socket)
    if socket.assigns.game_phase == :playing and is_nil(socket.assigns.timer_ref) do
      {:noreply, start_play_timer(socket)}
    else
      {:noreply, assign(socket, :playback_started_timeout_ref, nil)}
    end
  end

  def handle_info(:countdown_tick, socket) do
    case socket.assigns.countdown_sec do
      n when is_integer(n) and n > 1 ->
        socket = assign(socket, :countdown_sec, n - 1)
        Process.send_after(self(), :countdown_tick, 1000)
        {:noreply, socket}
      1 ->
        duration = socket.assigns.play_duration_sec
        ref = Process.send_after(self(), :playback_started_timeout, 10_000)
        socket =
          socket
          |> assign(:game_phase, :playing)
          |> assign(:countdown_sec, nil)
          |> assign(:time_left_sec, duration)
          |> assign(:playback_started_timeout_ref, ref)

        payload = %{uri: socket.assigns.current_track.uri, token: socket.assigns.spotify_token}
payload = if id = socket.assigns[:spotify_device_id], do: Map.put(payload, :device_id, id), else: payload
{:noreply, push_event(socket, "play_track", payload)}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("show_playlists", _params, socket) do
    # Bei "Neues Spiel" (running_game vorhanden) den alten Spielstand löschen
    socket =
      if socket.assigns.running_game do
        socket
        |> assign(:played_track_ids, [])
        |> assign(:running_game, nil)
        |> push_event("clear_game_state", %{})
      else
        socket
      end

    socket = assign(socket, :show_start_menu, false)
    # Nur von der API laden, wenn wir noch keine Playlists haben (Cache/vorheriger Load)
    if is_nil(socket.assigns.playlists) do
      send(self(), :load_playlists)
    end
    {:noreply, socket}
  end

  def handle_event("running_game_available", %{"playlist_id" => id, "playlist_name" => name}, socket)
      when is_binary(id) and id != "" do
    {:noreply, assign(socket, :running_game, %{id: id, name: name})}
  end

  def handle_event("running_game_available", _params, socket) do
    {:noreply, assign(socket, :running_game, nil)}
  end

  def handle_event("continue_game", %{"id" => id, "name" => name}, socket) do
    if rate_limit_active?(socket) do
      {:noreply, assign(socket, :playlists_error, rate_limit_blocked_message(socket))}
    else
      socket =
        socket
        |> assign(:tracks_loading, true)
        |> assign(:playlists_error, nil)
        |> assign(:game_started, true)
        |> assign(:selected_playlist, %{id: id, name: name})

      send(self(), {:load_playlist_tracks, id})
      {:noreply, socket}
    end
  end

  def handle_event("back_to_start_menu", _params, socket) do
    # Playlists und tracks_cache NICHT löschen – spart API-Requests beim nächsten Klick
    {:noreply,
     socket
     |> assign(:show_start_menu, true)
     |> assign(:selected_playlist, nil)
     |> assign(:playlists_loading, false)
     |> assign(:playlists_error, nil)
     |> cancel_refresh_timer()
     |> cancel_rate_limit_retry()
     |> push_event("check_running_game", %{})}
  end

  @impl true
  def handle_event("select_playlist", %{"id" => id, "name" => name}, socket) do
    if rate_limit_active?(socket) do
      {:noreply, assign(socket, :playlists_error, rate_limit_blocked_message(socket))}
    else
      socket =
        socket
        |> assign(:tracks_loading, true)
        |> assign(:playlists_error, nil)
        |> assign(:game_started, false)
        |> assign(:selected_playlist, %{id: id, name: name})
        |> compute_phase()

      send(self(), {:load_playlist_tracks, id})
      {:noreply, socket}
    end
  end

  # User bestätigt Playlist im Detail-Screen → Spiel starten
  def handle_event("start_playlist", _params, socket) do
    {:noreply,
     socket
     |> assign(:game_started, true)
     |> assign(:game_phase, :idle)
     |> compute_phase()}
  end

  def handle_event("load_playlists", _params, socket) do
    if rate_limit_active?(socket) do
      {:noreply, assign(socket, :playlists_error, rate_limit_blocked_message(socket))}
    else
      socket =
        socket
        |> assign(:playlists_error, nil)
        |> assign(:playlists_loading, true)

      send(self(), :load_playlists)
      {:noreply, socket}
    end
  end

  def handle_event("restore_playlists", %{"playlists" => list}, socket) do
    if socket.assigns.phase == :choose_playlist and is_list(list) and list != [] do
      playlists =
        Enum.map(list, fn p ->
          base = %{id: p["id"], name: p["name"]}
          base = case p["track_count"] do
            c when is_integer(c) -> Map.put(base, :track_count, c)
            _ -> base
          end
          if p["snapshot_id"], do: Map.put(base, :snapshot_id, p["snapshot_id"]), else: base
        end)

      {:noreply, assign(socket, :playlists, playlists)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("retry", _params, socket) do
    if rate_limit_active?(socket) do
      {:noreply, assign(socket, :playlists_error, rate_limit_blocked_message(socket))}
    else
      socket = assign(socket, :playlists_error, nil)
      if socket.assigns.selected_playlist do
        socket = assign(socket, :tracks_loading, true)
        send(self(), {:load_playlist_tracks, socket.assigns.selected_playlist.id})
      else
        send(self(), :load_playlists)
      end
      {:noreply, socket}
    end
  end

  # Schritt 1: Kategorie auslosen (später mit Animation). Track wird noch NICHT gewählt.
  def handle_event("next_round", _params, socket) do
    category = FiveSongs.Categories.pick_random()

    {:noreply,
     socket
     |> assign(:current_category, category)
     |> assign(:current_track, nil)
     |> assign(:reveal_data, nil)
     |> assign(:show_reveal, false)
     |> assign(:game_phase, :category_picked)}
  end

  # Schritt 2: Song zufällig wählen und Countdown starten
  def handle_event("play_song", _params, socket) do
    valid_tracks = socket.assigns.valid_tracks
    played = socket.assigns.played_track_ids || []
    available = Enum.reject(valid_tracks, fn t -> t.id in MapSet.new(played) end)

    case available do
      [] ->
        {:noreply, socket}

      _ ->
        track = FiveSongs.Tracks.pick_random_track(available)
        new_played = [track.id | played]
        pl = socket.assigns.selected_playlist

        socket =
          socket
          |> assign(:current_track, track)
          |> assign(:played_track_ids, new_played)
          |> assign(:game_phase, :countdown)
          |> assign(:countdown_sec, 3)
          |> assign(:time_left_sec, nil)
          |> push_event("save_game_state", %{
            playlist_id: pl.id,
            playlist_name: pl.name,
            played_track_ids: new_played
          })

        Process.send_after(self(), :countdown_tick, 1000)
        {:noreply, socket}
    end
  end

  def handle_event("stop_round", _params, socket) do
    socket = socket |> cancel_timer() |> cancel_playback_started_timeout()
    reveal_data = socket.assigns.current_track && FiveSongs.Tracks.reveal_data(socket.assigns.current_track)

    {:noreply,
     socket
     |> assign(:game_phase, :reveal)
     |> assign(:reveal_data, reveal_data)
     |> assign(:show_reveal, false)
     |> assign(:time_left_sec, nil)
     |> push_event("pause_track", pause_payload(socket))}
  end

  def handle_event("show_reveal", _params, socket) do
    {:noreply, assign(socket, :show_reveal, true)}
  end

  def handle_event("restore_state", %{"played_track_ids" => ids}, socket) do
    list = if is_list(ids), do: ids, else: []
    {:noreply, assign(socket, :played_track_ids, list)}
  end

  def handle_event("back_to_playlists", _params, socket) do
    was_playing = socket.assigns.game_phase in [:playing, :countdown]

    socket =
      socket
      |> cancel_timer()
      |> cancel_playback_started_timeout()
      |> cancel_refresh_timer()
      |> cancel_rate_limit_retry()
      |> assign(:selected_playlist, nil)
      |> assign(:valid_tracks, [])
      |> assign(:played_track_ids, [])
      |> assign(:tracks_loading, false)
      |> assign(:playlists_error, nil)
      |> assign(:game_started, false)
      |> assign(:year_range, nil)
      |> assign(:game_phase, :idle)
      |> assign(:current_track, nil)
      |> assign(:current_category, nil)
      |> assign(:reveal_data, nil)
      |> assign(:show_reveal, false)
      |> assign(:time_left_sec, nil)
      |> assign(:timer_ref, nil)
      |> assign(:countdown_sec, nil)
      |> compute_phase()
      |> schedule_token_refresh()

    socket = if was_playing, do: push_event(socket, "pause_track", pause_payload(socket)), else: socket

    {:noreply, socket}
  end

  # Client meldet, dass Spotify wirklich abspielt → Timer starten (Sync mit Playback)
  def handle_event("playback_started", _params, socket) do
    if socket.assigns.game_phase == :playing and is_nil(socket.assigns.timer_ref) do
      socket = cancel_playback_started_timeout(socket)
      {:noreply, start_play_timer(socket)}
    else
      {:noreply, socket}
    end
  end

  defp start_play_timer(socket) do
    duration_sec = socket.assigns.play_duration_sec
    ref = Process.send_after(self(), :time_up, duration_sec * 1000)
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

  defp cancel_playback_started_timeout(socket) do
    if ref = socket.assigns[:playback_started_timeout_ref] do
      Process.cancel_timer(ref)
    end
    assign(socket, :playback_started_timeout_ref, nil)
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

  defp rate_limit_message(%{retry_after: seconds}) when is_integer(seconds) and seconds > 0 do
    minutes = div(seconds, 60)
    rest_sec = rem(seconds, 60)
    time =
      cond do
        minutes > 0 and rest_sec > 0 -> "#{minutes} Min. #{rest_sec} Sek."
        minutes > 0 -> "#{minutes} Min."
        true -> "#{seconds} Sek."
      end
    if seconds > @max_auto_retry_sec do
      "Spotify-Sperre: #{time}. Kein Auto-Retry – bitte warte ab, Retries verlängern die Sperre!"
    else
      "Spotify Rate-Limit erreicht. Automatischer Retry in #{time}."
    end
  end
  defp rate_limit_message(_), do: "Spotify Rate-Limit erreicht. Automatischer Retry in Kürze."

  # Pulsgeschwindigkeit für die rote Vignette in den letzten 10 Sekunden.
  # Je weniger Zeit, desto schneller blinkt es.
  defp vignette_pulse_speed(sec) when sec <= 2, do: "0.25s"
  defp vignette_pulse_speed(sec) when sec <= 5, do: "0.5s"
  defp vignette_pulse_speed(sec) when sec <= 8, do: "0.8s"
  defp vignette_pulse_speed(_sec), do: "1.2s"

  # Jahrspanne (min/max) aus den Album-Release-Dates der Tracks berechnen
  defp compute_year_range(tracks) when is_list(tracks) do
    years =
      tracks
      |> Enum.map(fn t -> t.album && t.album.release_date end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn date ->
        case String.split(date, "-") do
          [y | _] when byte_size(y) == 4 ->
            case Integer.parse(y) do
              {n, _} -> n
              :error -> nil
            end
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    case years do
      [] -> nil
      _ -> {Enum.min(years), Enum.max(years)}
    end
  end

  # snapshot_id aus der Playlist-Liste holen, um zu prüfen ob der Track-Cache noch gültig ist
  defp get_playlist_snapshot(playlists, playlist_id) when is_list(playlists) do
    case Enum.find(playlists, fn p -> p.id == playlist_id end) do
      %{snapshot_id: sid} -> sid
      _ -> nil
    end
  end
  defp get_playlist_snapshot(_, _), do: nil

  # Automatischer Retry bei 429: nur wenn Retry-After <= 5 Min (300s).
  # Bei laengeren Sperren (z.B. 1323 Min) wuerde ein Retry die Sperre verlängern.
  defp schedule_rate_limit_retry(socket, message, %{retry_after: seconds})
       when is_integer(seconds) and seconds > 0 and seconds <= @max_auto_retry_sec do
    cancel_rate_limit_retry(socket)
    ref = Process.send_after(self(), message, seconds * 1000)
    assign(socket, :rate_limit_retry_ref, ref)
  end
  defp schedule_rate_limit_retry(socket, _message, %{retry_after: seconds})
       when is_integer(seconds) and seconds > @max_auto_retry_sec do
    # Sperre zu lang → NICHT automatisch retrien, das macht es nur schlimmer
    cancel_rate_limit_retry(socket)
    assign(socket, :rate_limit_blocked_until, System.monotonic_time(:second) + seconds)
  end
  defp schedule_rate_limit_retry(socket, message, _details) do
    # Kein Retry-After bekannt → nach 60 Sek. nochmal versuchen
    cancel_rate_limit_retry(socket)
    ref = Process.send_after(self(), message, 60_000)
    assign(socket, :rate_limit_retry_ref, ref)
  end

  defp cancel_rate_limit_retry(socket) do
    if ref = socket.assigns[:rate_limit_retry_ref] do
      Process.cancel_timer(ref)
    end
    socket
    |> assign(:rate_limit_retry_ref, nil)
    |> assign(:rate_limit_blocked_until, nil)
  end

  # Prüft ob wir gerade in einer langen Sperre stecken (> 5 Min Retry-After)
  defp rate_limit_active?(socket) do
    case socket.assigns[:rate_limit_blocked_until] do
      nil -> false
      until -> System.monotonic_time(:second) < until
    end
  end

  defp rate_limit_blocked_message(socket) do
    case socket.assigns[:rate_limit_blocked_until] do
      nil -> "Spotify Rate-Limit aktiv. Bitte warte etwas."
      until ->
        remaining = max(until - System.monotonic_time(:second), 0)
        minutes = div(remaining, 60)
        if minutes > 0 do
          "Spotify-Sperre aktiv. Bitte warte noch ca. #{minutes} Min. Retries während der Sperre verlängern sie!"
        else
          "Spotify-Sperre aktiv. Bitte warte noch etwas."
        end
    end
  end

  defp pause_payload(socket) do
    base = %{token: socket.assigns.spotify_token}
    if id = socket.assigns[:spotify_device_id], do: Map.put(base, :device_id, id), else: base
  end

  # Lädt alle Tracks einer Playlist (Pagination). max_items begrenzen spart Requests (Rate Limit).
  # Siehe docs/SPOTIFY_RATE_LIMIT.md für alle API-Aufrufe.
  defp fetch_all_playlist_items(playlist_id, token, max_items \\ 200) do
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
