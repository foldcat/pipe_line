# PipeLine

Relay messages to multiple Discord channels.

# To Host 

First of all, install Elixir and Mix.

Once completed, create a `config/config.exs` shown in the config section.

```bash
# fetch deps
mix deps.get

# setup the sqlite3 database
mix ecto.create
mix ecto.migrate
```

After that, PipeLine is ready.

```bash 
mix run --no-halt
# or 
iex -S mix
```

# Manual 

The bot's prefix is `>!`. Execute `>! help` and `>! info` for the manual.

To register admin, run `PipeLine.Commands.Admin.register_admin_iex("userid")` in
iex to do just that. `PipeLine.Commands.Admin.delete_admin_iex("userid")` exists
in case you regret your decision.

# Config 

We do not include a `config/config.exs` due to the inclusion of a token.

Use the below as an starting point.

```elixir

import Config

config :nostrum,
  token: "token",
  gateway_intents: :all

config :logger,
  level: :info

config :pipe_line,
  ecto_repos: [PipeLine.Database.Repo]

config :pipe_line, PipeLine.Database.Repo, database: "./database.db"

# config the cache size to prevent excessive memory usage  

# influence how many messages can be edited and deleted
config :pipe_line,
  max_msg_cache_size: 500

# influence how many messages which it's author's id can be queried `>! getowner` command
config :pipe_line,
  max_owner_cache_size: 500

# influence the `>! rules` command
config :pipe_line,
  rules: [
    "use common sense"
  ]

# censor the words below
config :pipe_line,
  blacklist: ~w[
skibidi
bussin 
fanum
gyatt
rizz 
]

# config hammer for rate limit
# for advanced hosts only
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}
```

# License 

Copyright 2024 foldcat

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
