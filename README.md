# Studio54

[![Hex version](https://img.shields.io/hexpm/v/studio54.svg "Hex version")](https://hex.pm/packages/studio54)
![Hex downloads](https://img.shields.io/hexpm/dt/studio54.svg "Hex downloads")

## Installation

The package can be installed
by adding `studio54` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:studio54, "~> 0.4"}
  ]
end
```
Add `:studio54` to applications and then run:

```bash
mix studio54_setup
# or if you want to cleanup everything:
mix studio54_setup clean

```

## Config

```elixir

config :studio54,                                                                                                                                                                          
     host: "192.168.10.1",  # device gateway ip
     name: "admin",         # username
     password: "admin",     # password
     tick: 1000,            # new message check interval
     delay_on_record: 2000, # wait time to handle multi part messages
     mno: "IR-TCI",         # device sim mobile network operator
     tz_offset: 12600,      # Timezone offset
     msisdn: "989906767514" # device sim number
```

## Usage

- Sending SMS:
```elixir
Studio54.send_sms 989120228207, "wow"
```

- Reading inbox
```elixir
Studio54.get_inbox new: true
```

- Subscribe to incomming message event:
```elixir
Studio54.Db.add_message_event "989120228207", 60, IO, :inspect, "[\\d]{5}"
```

This will call `IO.inspect/1` with incomming message as argument when message
sent from `+989-1202-228-207` and body contains a 5 digit number!.


## Running tests:

```bash
MIX_ENV=test mix do studio54_setup clean, test --trace --cover
```

- For more information, look at [test file](/test/studio54_test.exs).
