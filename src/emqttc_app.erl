%%%-------------------------------------------------------------------
%% @doc emqttc public API
%% @end
%%%-------------------------------------------------------------------

-module(emqttc_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    emqttc_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
