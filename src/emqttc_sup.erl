%%%-------------------------------------------------------------------
%%% @doc
%%% @end
%%%-------------------------------------------------------------------
-module(emqttc_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    AChild = #{
        id => emqttc,
        start => {emqttc, start_link, []},
        restart => transient,
        shutdown => 2000,
        type => worker,
        modules => [emqttc]
    },
    {ok, {#{
        strategy => simple_one_for_one,
        intensity => 5,
        period => 30},
        [AChild]}
    }.
