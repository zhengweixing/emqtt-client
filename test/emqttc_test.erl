-module(emqttc_test).
-behavior(emqttc).

-export([start/0]).

-export([start/1, handle_msg/2]).

-record(state, {}).

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


start(ClientId) ->
    io:format("~p connect successful!~n", [ClientId]),
    {ok, #state{}}.

handle_msg(Info, _State) ->
    io:format("handle msg ~p~n", [Info]),
    ok.
