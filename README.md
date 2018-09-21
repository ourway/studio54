# Studio54

[![Hex version](https://img.shields.io/hexpm/v/studio54.svg "Hex version")](https://hex.pm/packages/studio54)
![Hex downloads](https://img.shields.io/hexpm/dt/studio54.svg "Hex downloads")

## Installation

The package can be installed
by adding `studio54` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:studio54, "~> 0.2"}
  ]
end
```
Add `:studio54` to applications.

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

- For more information, look at [test file](/test/studio54_test.exs).
