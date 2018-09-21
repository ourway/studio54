defmodule Studio54.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Supervisor
  require Logger

  alias Studio54.DbSetup, as: DbSetup

  @impl true
  def start(_type, _args) do
    # List all child processes to be supervised
    db_setup()

    children = [
      # Starts a worker by calling: Studio54.Worker.start_link(arg)
      worker(Studio54.Starter, [%{}])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def init(args) do
    {:ok, args}
  end

  def db_setup do
    :ok = DbSetup.create_schema()
    :ok = DbSetup.create_message_table()
    :ok = DbSetup.create_message_event_table()
    :ok = DbSetup.create_state_table()
    :ok
  end
end
