defmodule LiveIsolatedComponent do
  @moduledoc """
  Documentation for `LiveIsolatedComponent`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> LiveIsolatedComponent.hello()
      :world

  """

  import Phoenix.ConnTest, only: [build_conn: 0]
  import Phoenix.LiveViewTest, only: [live_isolated: 3, render: 1]

  @assigns_key "live_isolated_component_assigns"
  @assign_updates_event "live_isolated_component_update_assigns_event"
  @callbacks_agent_key "live_isolated_component_callbacks_agent"
  @module_key "live_isolated_component_module"

  defmodule View do
    use Phoenix.LiveView

    @assigns_key "live_isolated_component_assigns"
    @assign_updates_event "live_isolated_component_update_assigns_event"
    @callbacks_agent_key "live_isolated_component_callbacks_agent"
    @module_key "live_isolated_component_module"

    def mount(_params, session, socket) do
      socket =
        socket
        |> assign(:module, session[@module_key])
        |> assign(:assigns, session[@assigns_key])
        |> assign(:callbacks_agent, session[@callbacks_agent_key])

      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
        <.live_component
          id="some-unique-id"
          module={@module}
          {@assigns}
          />
      """
    end

    def handle_event(event, params, socket) do
      handle_event = get_handle_event(socket)

      handle_event.(event, params, socket)
    end

    def handle_info({@assign_updates_event, keyword_or_map}, socket) do
      {:noreply, component_assign(socket, keyword_or_map)}
    end

    defp component_assign(socket, map) when is_map(map) do
      update(socket, :assigns, &Map.merge(&1, map))
    end

    defp component_assign(socket, other_enum) do
      component_assign(socket, Enum.into(other_enum, %{}))
    end

    defp get_handle_event(%{assigns: %{callbacks_agent: agent}}) do
      case Agent.get(agent, & &1) do
        %{handle_event: nil} ->
          fn _event, _params, socket -> {:noreply, socket} end

        %{handle_event: handler} ->
          handler

        _ ->
          fn _event, _params, socket -> {:noreply, socket} end
      end
    end
  end

  def live_assign(view, keyword_or_map) do
    send(view.pid, {@assign_updates_event, keyword_or_map})

    render(view)

    view
  end

  def live_assign(view, key, value) do
    live_assign(view, %{key => value})
  end

  defmacro live_isolated_component(module, opts) do
    quote do
      opts = if is_map(unquote(opts)), do: [assigns: unquote(opts)], else: unquote(opts)

      {:ok, callbacks_agent} =
        Agent.start_link(fn ->
          %{
            handle_event: Keyword.get(opts, :handle_event)
          }
        end)

      live_isolated(build_conn(), View,
        session: %{
          unquote(@module_key) => unquote(module),
          unquote(@assigns_key) => Keyword.get(opts, :assigns, %{}),
          unquote(@callbacks_agent_key) => callbacks_agent
        }
      )
    end
  end
end
