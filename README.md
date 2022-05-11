# emqtt-client
mqtt client for erlang

## Examples
```erlang
-module(emqttc_test).
-behavior(emqttc).

-export([start/0]).

-export([init/1, handle_msg/2, stop/2]).

-record(state, { id }).

start() ->
    Opts = [
        {host, "127.0.0.1"},
        {port, 1883},
        {username, "112233"},
        {password, "111111"}
    ],
    {ok, Pid} = emqttc:start(<<"testbook1111">>, ?MODULE, Opts),
    emqttc:subscribe(Pid, <<"test">>, [{qos, 1}]),
    emqttc:publish(Pid, <<"test">>, <<"hello">>, [{qos, 1}]).


init(ClientId) ->
    io:format("~p connect successful!~n", [ClientId]),
    {ok, #state{ id = clientId }}.

handle_msg(Info, State) ->
    io:format("Client(~p) handle msg ~p~n", [State#state.id, Info]),
    ok.

stop(Reason, State) ->
    io:format("Client(~p) stop reason:~p~n", [State#state.id, Reason]),
    ok.
```

## Use

Add the plugin to your rebar config:

```
{emqttc, {git, "https://github.com/zhengweixing/emqtt_client.git",
        {branch, main}}}
```


## License
Apache License Version 2.0
