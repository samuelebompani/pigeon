defmodule Pigeon.Pigeons.PigeonNames do
  @names ~w(
    Archimedes
    Biscuit
    Cleo
    Dottie
    Ernesto
    Flapjack
    Gnocchi
    Horatio
    Iggy
    Juniper
    Kazimir
    Lentil
    Mortimer
    Noodle
    Ottoline
    Pretzel
    Quillan
    Rhubarb
    Squidward
    Tuffet
    Ubaldo
    Vesper
    Waffles
    Xerxes
    Yolanda
    Zeppole
  )

  def random, do: Enum.random(@names)
  def all, do: @names
end
