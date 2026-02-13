defmodule FiveSongs.Categories do
  @moduledoc """
  Die 5 Spiel-Kategorien mit id, label und Farbe für die UI.
  """

  @categories [
    %{id: "year", label: "Jahr ±3", color: "#3B82F6"},
    %{id: "artist", label: "Interpret", color: "#10B981"},
    %{id: "title", label: "Titel", color: "#F59E0B"},
    %{id: "album", label: "Album", color: "#8B5CF6"},
    %{id: "genre", label: "Genre", color: "#EC4899"}
  ]

  def list, do: @categories

  def pick_random do
    Enum.random(@categories)
  end
end
