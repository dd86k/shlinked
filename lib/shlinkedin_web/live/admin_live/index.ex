defmodule ShlinkedinWeb.AdminLive.Index do
  use ShlinkedinWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    # KNOWN BUG: RIGHT WHEN YOU CREATE AN ACCOUNT, THIS BUTTON DOESN"T WORK! PROBLABLY NOT LOADED INTO SOCKET!
    socket = is_user(session, socket)

    {:ok, socket}
  end
end