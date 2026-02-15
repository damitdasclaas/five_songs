defmodule FiveSongs.Categories do
  @moduledoc """
  Die 5 Spiel-Kategorien mit id, label und Farbe für die UI.
  """

  @categories [
    %{id: "exact_year", label: "Genaues Erscheinungsjahr", color: "#3B82F6"},
    %{id: "decade", label: "Jahrzehnt", color: "#10B981"},
    %{id: "year_pm3", label: "Erscheinungsjahr ±3", color: "#F59E0B"},
    %{id: "artist", label: "Interpret", color: "#8B5CF6"},
    %{id: "title", label: "Titel", color: "#EC4899"}
  ]

  def list, do: @categories

  def pick_random do
    Enum.random(@categories)
  end
end
