defmodule Studio54 do
  @moduledoc """
  Studio54 is an effort to make use of HUAWEI LTE modems to act as a
  SMS gateway.
  iex > Studio54.Starter.start_worker
  """
  require Exml
  @name Application.get_env(:studio54, :name)
  @password Application.get_env(:studio54, :password)
  @host Application.get_env(:studio54, :host)
  #  @mno Application.get_env(:studio54, :mno)
  @base_url "http://#{@host}"
  @loginpath "#{@base_url}/api/user/login"
  #  @remindpath "#{@base_url}/api/user/remind"
  @tokenpath "http://#{@host}/api/webserver/SesTokInfo"
  @smspath "http://#{@host}/api/sms/send-sms"
  @countpath "http://#{@host}/api/sms/sms-count"
  @listpath "http://#{@host}/api/sms/sms-list"
  @deletepath "http://#{@host}/api/sms/delete-sms"
  @readpath "http://#{@host}/api/sms/set-read"
  @ussdsendpath "http://#{@host}/api/ussd/send"
  @ussdgetpath "http://#{@host}/api/ussd/get"
  @ussdstatuspath "http://#{@host}/api/ussd/status"

  @doc """
    This hash is special format used by HUAWEI modems.
    basicly, it's lower case of sha256 hash.
  """
  def gethash(inp) do
    :crypto.hash(:sha256, inp) |> Base.encode16() |> String.downcase()
  end

  @doc """
    Get SessionID cookie and Token.
  """
  def get_ses_token_info do
    doc = HTTPotion.get(@tokenpath) |> Map.get(:body) |> Exml.parse()
    sid = doc |> Exml.get("//SesInfo")
    token = doc |> Exml.get("//TokInfo")
    %{sid: sid, token: token}
  end

  def login do
    stdata = get_ses_token_info()
    passhash = gethash(@password) |> Base.encode64()
    psd = gethash(@name <> passhash <> stdata.token) |> Base.encode64()

    postdata = """
      <?xml version: "1.0" encoding="UTF-8"?>
        <request>
          <Username>#{@name}</Username>
          <Password>#{psd}</Password>
          <password_type>4</password_type>
        </request>
    """

    login_headers = [
      "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
      Origin: "http://#{@host}",
      Referer: "http://#{@host}/html/home.html",
      "X-Requested-With": "XMLHttpRequest",
      Cookie: stdata.sid,
      __RequestVerificationToken: stdata.token
    ]

    %HTTPotion.Response{
      :body => _body,
      :headers => %HTTPotion.Headers{
        :hdrs => %{
          "set-cookie" => cookie,
          "__requestverificationtokenone" => token1,
          "__requestverificationtokentwo" => token2
        }
      },
      :status_code => 200
    } = HTTPotion.post(@loginpath, body: postdata, headers: login_headers)

    %{sid: cookie, token1: token1, token2: token2}
  end

  def get_headers do
    %{:sid => sid, :token1 => token1} = login()

    [
      "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
      Origin: "http://#{@host}",
      Referer: "http://#{@host}/html/home.html",
      "X-Requested-With": "XMLHttpRequest",
      Cookie: sid,
      __RequestVerificationToken: token1
    ]
  end

  def send_sms(msisdn, text) do
    headers = get_headers()

    postdata = """
    <?xml version: "1.0" encoding="UTF-8"?>
    <request>
    <Index>-1</Index>
    <Priority>1000</Priority>
    <Phones>
    <Phone>#{msisdn}</Phone>
    </Phones>
    <Sca></Sca>
    <Content>#{text}</Content>
    <Length>#{text |> String.length()}</Length>
    <Reserved>1</Reserved>
    <Date>#{Timex.local() |> DateTime.to_string() |> binary_part(0, 19)}</Date>
    </request>
    """

    %HTTPotion.Response{:body => body, :status_code => 200} =
      HTTPotion.post(@smspath, body: postdata, headers: headers)

    case body |> Exml.parse() |> Exml.get("//response") do
      "OK" ->
        {:ok, true}

      nil ->
        {:error, false}
    end
  end

  def get_ussd_status(headers) do
    %HTTPotion.Response{:body => body, :status_code => 200} =
      HTTPotion.get(@ussdstatuspath, headers: headers)

    case body |> Exml.parse() |> Exml.get("//result") |> String.to_integer() do
      1 ->
        :timer.sleep(1_000)
        get_ussd_status(headers)

      0 ->
        :ready
    end
  end

  def send_ussd(command) do
    headers = get_headers()

    postdata = """
    <?xml version="1.0" encoding="UTF-8"?>
    <request>
      <content>#{command}</content>
      <codeType>CodeType</codeType>
      <timeout></timeout>
    </request>
    """

    %HTTPotion.Response{:body => body, :status_code => 200} =
      HTTPotion.post(@ussdsendpath, body: postdata, headers: headers)

    case body |> Exml.parse() |> Exml.get("//response") do
      "OK" ->
        :ready = get_ussd_status(headers)

        %HTTPotion.Response{:body => body, :status_code => 200} =
          HTTPotion.get(@ussdgetpath, headers: headers)

        {:ok, body |> Exml.parse() |> Exml.get("//content")}

      nil ->
        {:error, false}
    end
  end

  def get_credit do
    cmd = "*140*11#"
    {:ok, result} = send_ussd(cmd)
    %{"credit" => cr} = Regex.named_captures(~r/(?<credit>[\d]+) ریال/, result)
    cr |> String.to_integer()
  end

  def get_new_count do
    headers = get_headers()

    %HTTPotion.Response{:body => body, :status_code => 200} =
      HTTPotion.get(@countpath, headers: headers)

    {:ok, body |> Exml.parse() |> Exml.get("//LocalUnread") |> String.to_integer()}
  end

  def mark_as_read(idxs) do
    headers = get_headers()
    indexes = idxs |> Enum.map(fn i -> "<Index>#{i}</Index>" end)

    postdata = """
      <?xml version="1.0" encoding="UTF-8"?>
        <request>#{indexes}</request>
    """

    %HTTPotion.Response{:body => body, :status_code => 200} =
      HTTPotion.post(@readpath, body: postdata, headers: headers)

    case body |> Exml.parse() |> Exml.get("//response") do
      "OK" ->
        {:ok, true}

      nil ->
        {:error, false}
    end
  end

  def get_inbox(new: new) do
    case new do
      true ->
        {:ok, _, msgs} = get_box(1)
        nm = msgs |> Enum.filter(fn m -> m.new == true end)
        {:ok, nm |> length, nm}

      false ->
        get_box(1)
    end
  end

  def get_outbox do
    get_box(2)
  end

  def get_box(box) do
    headers = get_headers()

    postdata = """
    <?xml version="1.0" encoding="UTF-8"?>
    <request>
       <PageIndex>1</PageIndex>
       <ReadCount>50</ReadCount>
       <BoxType>#{box}</BoxType>
       <SortType>0</SortType>
       <Ascending>0</Ascending>
       <UnreadPreferred>1</UnreadPreferred>
    </request>
    """

    %HTTPotion.Response{:body => body, :status_code => 200} =
      HTTPotion.post(@listpath, body: postdata, headers: headers)

    doc = body |> Exml.parse()

    {:ok, doc |> Exml.get("//Count") |> String.to_integer(),
     case doc |> Exml.get("//Count") |> String.to_integer() do
       0 ->
         []

       1 ->
         [
           %{
             msisdn: doc |> Exml.get("//Message//Phone"),
             body: doc |> Exml.get("//Message//Content"),
             datetime: doc |> Exml.get("//Message/Date") |> NaiveDateTime.from_iso8601!(),
             index: doc |> Exml.get("//Message/Index") |> String.to_integer(),
             new: doc |> Exml.get("//Message/Smstat") |> String.to_integer() == 0
           }
         ]

       _ ->
         doc
         |> Exml.get("//Message/Index")
         |> Enum.map(fn i ->
           %{
             msisdn: doc |> Exml.get("//Message[Index='#{i}']//Phone"),
             body: doc |> Exml.get("//Message[Index='#{i}']//Content"),
             datetime:
               doc |> Exml.get("//Message[Index='#{i}']//Date") |> NaiveDateTime.from_iso8601!(),
             index: i |> String.to_integer(),
             new: doc |> Exml.get("//Message[Index='#{i}']//Smstat") |> String.to_integer() == 0
           }
         end)
     end}
  end

  def empty_index do
    {:ok, _count, messages} = get_inbox(new: false)
    {:ok, _count, messages2} = get_outbox()
    {:ok, _count, messages3} = get_box(3)
    headers = get_headers()

    indexes =
      (messages ++ messages2 ++ messages3)
      |> Enum.map(fn m ->
        "<Index>#{m.index}</Index>"
      end)
      |> Enum.join()

    postdata = """
    <?xml version: "1.0" encoding="UTF-8"?>
      <request>#{indexes}</request>
    """

    %HTTPotion.Response{:body => body, :status_code => 200} =
      HTTPotion.post(@deletepath, body: postdata, headers: headers)

    case body |> Exml.parse() |> Exml.get("//response") do
      "OK" ->
        {:ok, true}

      nil ->
        {:error, false}
    end
  end
end
