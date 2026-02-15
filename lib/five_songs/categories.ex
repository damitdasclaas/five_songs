defmodule FiveSongs.Categories do
  @moduledoc """
  Die 5 Spiel-Kategorien mit id, label und Farbe für die UI.
  """

  @categories [
    %{id: "exact_year", label: "Genaues Erscheinungsjahr", color: "#EC4899"},
    %{id: "decade", label: "Jahrzehnt", color: "#8B5CF6"},
    %{id: "year_pm3", label: "Erscheinungsjahr ±3", color: "#3B82F6"},
    %{id: "artist", label: "Interpret", color: "#F59E0B"},
    %{id: "title", label: "Titel", color: "#10B981"}
  ]

  def list, do: @categories

  def pick_random do
    Enum.random(@categories)
  end
end
