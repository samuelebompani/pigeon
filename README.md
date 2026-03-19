# Pigeon
![tests](https://github.com/samuelebompani/pigeon/actions/workflows/ci.yml/badge.svg)

A real-time chat app where every conversation comes with a shared virtual pigeon.

Built with **Elixir**, **Phoenix LiveView**, and **PostgreSQL**.

---

## What is this?

Pigeon is a direct messaging app with a twist: any two users can adopt a pigeon together. The pigeon lives in their chat, has a randomly assigned personality, gets hungry over time and occasionally speaks. Feed it or it'll complain.

---

## Features

- **Auth** — register and log in with a username and password (bcrypt hashed)
- **Real-time chat** — messages delivered instantly via Phoenix PubSub, no polling
- **Shared pigeons** — adopt a pigeon with another user through a request/accept flow
- **Pigeon personalities** — grumpy, affectionate, chaotic, lazy or dramatic
- **Hunger system** — pigeons get hungrier; feed them to keep them happy

---

## Stack

| Layer | Technology |
|---|---|
| Language | Elixir 1.15 |
| Framework | Phoenix 1.8 + LiveView |
| Database | PostgreSQL via Ecto |
| Real-time | Phoenix PubSub |
| Auth | bcrypt_elixir |
| Server | Bandit |

---

## Getting started

**Prerequisites:** Elixir 1.15+, PostgreSQL running locally.

```bash
# Install dependencies
mix deps.get

# Create and migrate the database
mix ecto.create
mix ecto.migrate

# Start the server
mix phx.server
```

Visit [`http://localhost:4000`](http://localhost:4000), register an account, and start chatting.

---

## How pigeons work

Each pigeon runs as a `GenServer` registered in a `Registry` under its chat topic.

```
adopt → PigeonState inserted (status: pending)
      → other user accepts → status: active, personality assigned
      → PigeonServer.start_link(topic) called
      → ticks every 8s: hunger +5, broadcasts update
      → feed: hunger -40, pigeon says something
      → hunger persisted to DB on every tick
```

Personalities affect what the pigeon says when hungry.

---

## Running tests

```bash
mix test
```