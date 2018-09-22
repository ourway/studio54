# Studio54

[![Hex version](https://img.shields.io/hexpm/v/studio54.svg "Hex version")](https://hex.pm/packages/studio54)
![Hex downloads](https://img.shields.io/hexpm/dt/studio54.svg "Hex downloads")

## Installation

The package can be installed
by adding `studio54` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:studio54, "~> 0.3"}
  ]
end
```
Add `:studio54` to applications and then run:

```bash
mix studio54_setup
mix studio54_setup 
# or if you want to cleanup everything:
mix studio54_setup clean

```

## Config

```elixir

config :studio54,                                                                                                                                                                          
     host: "192.168.10.1",
     name: "admin",
     password: "admin",
     delivery_webhook: "https://httpbin.org/post",
     mo_webhook: "https://httpbin.org/post",
     tick: 1000,
     delay_on_record: 2000,
     mno: "IR-TCI",
     tz_offset: 12600,
     msisdn: "989906767514
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
