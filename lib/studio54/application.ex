defmodule Studio54.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Supervisor
  # import Cachex.Spec

  @impl true
  def start(_type, _args) do
    :ok = :mnesia.start()
    # List all child processes to be supervised

    children = [
      # Starts a worker by calling: Studio54.Worker.start_link(arg)
      #      worker(Cachex, [
      #        :cache,
      #        [
      #          transactions: false,
      #          hooks: [
      #            hook(module: Studio54.Hooks)
      #          ]
      #        ]
      #      ]),
      #
      #

      worker(
        ConCache,
        [
          [
            name: :box_cache,
            ttl_check_interval: :timer.seconds(1),
            global_ttl: :timer.seconds(2)
          ]
        ],
        id: :box_cache_worker
      ),
      worker(
        ConCache,
        [
          [
            name: :message_cache,
            ttl_check_interval: :timer.seconds(1),
            global_ttl: :infinity,
            callback: fn data ->
              case data do
                {:delete, _pid, sender} ->
                  Studio54.Db.add_incomming_message(sender)

                _ ->
                  :i_dont_care
              end
            end
          ]
        ],
        id: :message_cache_worker
      ),
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
end

defmodule Mix.Tasks.Studio54Setup do
  use Mix.Task
  require Logger
  alias Studio54.DbSetup, as: DbSetup

  @shortdoc "Simply runs the Hello.say/0 function"
  def run(mode) do
    case mode do
      ["clean"] ->
        :ok = DbSetup.delete_schema()

      [] ->
        :continue
    end

    :ok = DbSetup.create_schema()
    :ok = DbSetup.create_message_table()
    :ok = DbSetup.create_message_event_table()
    :ok = DbSetup.create_state_table()
    :ok
  end
end
