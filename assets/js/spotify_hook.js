const PLAYLIST_CACHE_KEY = "five_songs_playlists";
const GAME_STATE_KEY = "five_songs_game_state";
const CURRENT_GAME_KEY = "five_songs_current_game";

const SpotifyPlayerHook = {
  player: null,
  deviceId: null,
  pendingPlay: null,

  mounted() {
    this.handleEvent("play_track", ({ uri, token, device_id }) => {
      if (token) this.lastToken = token;
      this.pendingPlay = { uri, token, device_id };
      if (device_id) {
        this.playUri(uri, token, device_id);
        this.pendingPlay = null;
      } else {
        this.ensurePlayerThenPlay(token);
      }
    });
    this.handleEvent("pause_track", (payload) => {
      const token = payload?.token || this.lastToken;
      if (token) {
        const url = payload?.device_id
          ? `https://api.spotify.com/v1/me/player/pause?device_id=${payload.device_id}`
          : "https://api.spotify.com/v1/me/player/pause";
        fetch(url, {
          method: "PUT",
          headers: { "Authorization": `Bearer ${token}` }
        }).catch(() => {});
      }
      if (this.player) this.player.pause();
    });
    this.handleEvent("cache_playlists", ({ playlists }) => {
      // snapshot_id wird mitgespeichert, damit der Server Tracks-Cache validieren kann
      if (playlists && playlists.length) {
        try { sessionStorage.setItem(PLAYLIST_CACHE_KEY, JSON.stringify(playlists)); } catch (_) {}
      }
    });
    this.handleEvent("request_saved_state", ({ playlist_id }) => {
      try {
        const raw = localStorage.getItem(GAME_STATE_KEY);
        const all = raw ? JSON.parse(raw) : {};
        const state = all[playlist_id];
        const played = state?.played_track_ids;
        if (Array.isArray(played) && played.length) {
          this.pushEvent("restore_state", { played_track_ids: played });
        }
      } catch (_) {}
    });
    this.handleEvent("save_game_state", ({ playlist_id, playlist_name, played_track_ids }) => {
      try {
        const raw = localStorage.getItem(GAME_STATE_KEY);
        const all = raw ? JSON.parse(raw) : {};
        all[playlist_id] = { playlist_name, played_track_ids: played_track_ids || [] };
        localStorage.setItem(GAME_STATE_KEY, JSON.stringify(all));
        if (playlist_id && (played_track_ids?.length ?? 0) > 0) {
          localStorage.setItem(CURRENT_GAME_KEY, JSON.stringify({ playlist_id, playlist_name }));
        }
      } catch (_) {}
    });
    this.handleEvent("check_running_game", () => {
      try {
        const cur = localStorage.getItem(CURRENT_GAME_KEY);
        if (!cur) {
          this.pushEvent("running_game_available", {});
          return;
        }
        const { playlist_id, playlist_name } = JSON.parse(cur);
        const raw = localStorage.getItem(GAME_STATE_KEY);
        const all = raw ? JSON.parse(raw) : {};
        const state = all[playlist_id];
        const played = state?.played_track_ids;
        if (playlist_id && Array.isArray(played) && played.length > 0) {
          this.pushEvent("running_game_available", { playlist_id, playlist_name });
        } else {
          this.pushEvent("running_game_available", {});
        }
      } catch (_) {
        this.pushEvent("running_game_available", {});
      }
    });
    try {
      const phase = this.el.dataset?.phase;
      if (phase === "login") {
        sessionStorage.removeItem(PLAYLIST_CACHE_KEY);
      } else if (phase === "choose_playlist") {
        const raw = sessionStorage.getItem(PLAYLIST_CACHE_KEY);
        if (raw) {
          const playlists = JSON.parse(raw);
          if (Array.isArray(playlists) && playlists.length) this.pushEvent("restore_playlists", { playlists });
        }
      }
    } catch (_) {}
  },

  ensurePlayerThenPlay(token) {
    if (this.player && this.deviceId) {
      this.playUri(this.pendingPlay.uri, this.pendingPlay.token, this.deviceId);
      this.pendingPlay = null;
      return;
    }
    if (this.player) {
      this.player.connect();
      return;
    }
    if (typeof window.Spotify === "undefined") {
      window.onSpotifyWebPlaybackSDKReady = () => this.initPlayer(token);
      return;
    }
    this.initPlayer(token);
  },

  initPlayer(token) {
    this.player = new window.Spotify.Player({
      name: "5songs (Browser)",
      getOAuthToken: (cb) => cb(token),
      volume: 1
    });
    this.player.addListener("ready", ({ device_id }) => {
      this.deviceId = device_id;
      if (this.pendingPlay) {
        this.playUri(this.pendingPlay.uri, this.pendingPlay.token, device_id);
        this.pendingPlay = null;
      }
    });
    this.player.addListener("not_ready", () => {});
    this.player.connect();
  },

  playUri(uri, token, deviceId) {
    const targetId = deviceId || this.deviceId;
    if (!targetId || !uri || !token) return;
    this._playbackStartedSent = false;
    const isExternalDevice = deviceId && deviceId !== this.deviceId;
    fetch(`https://api.spotify.com/v1/me/player/play?device_id=${targetId}`, {
      method: "PUT",
      body: JSON.stringify({ uris: [uri] }),
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"
      }
    }).then(() => {
      if (isExternalDevice) {
        setTimeout(() => this.pushEvent("playback_started", {}), 500);
      } else {
        this.waitForPlaybackStarted();
      }
    }).catch(() => {});
  },

  waitForPlaybackStarted() {
    if (!this.player) return;
    this.player.addListener("player_state_changed", (state) => {
      if (this._playbackStartedSent) return;
      if (state && !state.paused) {
        this._playbackStartedSent = true;
        this.pushEvent("playback_started", {});
      }
    });
  }
};

export default SpotifyPlayerHook;
