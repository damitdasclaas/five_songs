const PLAYLIST_CACHE_KEY = "five_songs_playlists";

const SpotifyPlayerHook = {
  player: null,
  deviceId: null,
  pendingPlay: null,

  mounted() {
    this.handleEvent("play_track", ({ uri, token }) => {
      this.pendingPlay = { uri, token };
      this.ensurePlayerThenPlay(token);
    });
    this.handleEvent("pause_track", () => {
      if (this.player) this.player.pause();
    });
    this.handleEvent("cache_playlists", ({ playlists }) => {
      if (playlists && playlists.length) {
        try { sessionStorage.setItem(PLAYLIST_CACHE_KEY, JSON.stringify(playlists)); } catch (_) {}
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
      this.playUri(this.pendingPlay.uri, this.pendingPlay.token);
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
      name: "5songs",
      getOAuthToken: (cb) => cb(token),
      volume: 1
    });
    this.player.addListener("ready", ({ device_id }) => {
      this.deviceId = device_id;
      if (this.pendingPlay) {
        this.playUri(this.pendingPlay.uri, this.pendingPlay.token);
        this.pendingPlay = null;
      }
    });
    this.player.addListener("not_ready", () => {});
    this.player.connect();
  },

  playUri(uri, token) {
    if (!this.deviceId || !uri || !token) return;
    this._playbackStartedSent = false;
    fetch(`https://api.spotify.com/v1/me/player/play?device_id=${this.deviceId}`, {
      method: "PUT",
      body: JSON.stringify({ uris: [uri] }),
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"
      }
    }).then(() => {
      this.waitForPlaybackStarted();
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
