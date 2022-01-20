-module(emqttc).

-behaviour(gen_server).

-export([start/3, start/2, stop/1, subscribe/3, publish/4, unsubscribe/2]).
-export([start_link/4, start_link/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


-record(state, {mod, clientid, opts, client, topics = [], child_state}).

-type message() :: {deliver,  Message :: map()} |
                   {puback,  Ack :: map()}.

-callback start(ClientId :: binary()) ->
    {ok, State :: any()} | {error, Reason :: any()}.

-callback handle_msg(Info, ClientId, State) -> ok | {ok, State} when
    Info :: message(),
    ClientId :: binary(),
    State :: any().

-callback stop(Reason :: any(), ClientId :: binary(), State :: any()) ->
    ok.

subscribe(Pid, Topic, SubOpts) ->
    gen_server:call(Pid, {sub, Topic, SubOpts}).

unsubscribe(Pid, Topic) ->
    gen_server:call(Pid, {unsub, Topic}).

publish(Pid, Topic, Payload, PubOpts) ->
    gen_server:call(Pid, {pub, Topic, Payload, PubOpts}).


start(Mod, Opts) ->
    supervisor:start_child(emqttc_sup, [Mod, Opts]).

start(Name, Mod, Opts) ->
    supervisor:start_child(emqttc_sup, [Name, Mod, Opts]).

stop(Pid) ->
    gen_server:call(Pid, stop).


start_link(ClientId, Mod, Opts) ->
    gen_server:start_link(?MODULE, [ClientId, Mod, Opts], []).

start_link(Name, ClientId, Mod, Opts) ->
    gen_server:start_link({local, Name}, ?MODULE, [ClientId, Mod, Opts], []).


init([ClientId, Mod, Opts]) ->
    case do_connect(ClientId, Opts) of
        {ok, ConnPid, _Props} ->
            case Mod:init(ClientId) of
                {ok, ChildState} ->
                    process_flag(trap_exit, true),
                    {ok, #state{
                        clientid = ClientId,
                        mod = Mod,
                        opts = Opts,
                        child_state = ChildState,
                        client = ConnPid
                    }};
                {stop, Reason} ->
                    {stop, Reason}
            end;
        {error, Reason} ->
            {stop, Reason}
    end.

handle_call(stop, _From, #state{client = ConnPid} = State) ->
    ok = emqtt:disconnect(ConnPid),
    ok = emqtt:stop(ConnPid),
    {stop, normal, ok, State};

handle_call({pub, Topic, Payload, PubOpts}, _From, #state{client = Client} = State) ->
    Reply =
        case lists:keyfind(qos, 1, PubOpts) of
            0 ->
                emqtt:publish(Client, Topic, #{}, Payload, PubOpts);
            _ ->
                case emqtt:publish(Client, Topic, #{}, Payload, PubOpts) of
                    {ok, _PktId} ->
                        ok;
                    {error, Reason} ->
                        {error, Reason}
                end
        end,
    {reply, Reply, State};

handle_call({unsub, Topic}, _From, #state{client = Client, topics = Topics} = State) ->
    Reply = emqtt:unsubscribe(Client, #{}, Topic),
    {reply, Reply, State#state{topics = lists:delete(Topic, Topics)}};

handle_call({sub, Topic, SubOpts}, _From, #state{topics = Topics} = State) ->
    case lists:keyfind(Topic, 1, Topics) of
        false ->
            case do_subscribe(Topic, SubOpts, State) of
                {ok, Properties, ReasonCode, NewState} ->
                    {reply, {ok, Properties, ReasonCode}, NewState};
                {error, Reason} ->
                    {reply, {error, Reason}, State}
            end;
        _ ->
            {reply, {error, duplicate}, State}
    end;

handle_call(_Request, _From, State = #state{}) ->
    {reply, ok, State}.

handle_cast(_Request, State = #state{}) ->
    {noreply, State}.

handle_info({publish, Msg}, #state{mod = Mod, clientid = ClientId} = State) ->
    case Mod:handle_msg({deliver,  Msg}, ClientId, State#state.child_state) of
        ok ->
            {noreply, State};
        {ok, NewChildState} ->
            {noreply, State#state{child_state = NewChildState}}
    end;

handle_info({puback, Ack}, #state{ mod = Mod, clientid = ClientId } = State) ->
    case Mod:handle_msg({puback, Ack}, ClientId, State#state.child_state) of
        ok ->
            {noreply, State};
        {ok, NewChildState} ->
            {noreply, State#state{child_state = NewChildState}}
    end;

handle_info({'EXIT', Pid, Reason}, #state{client = Pid} = State) ->
    logger:error("MQTT Client ~p stop, ~p~n", [Pid, Reason]),
    handle_info(reconnect, State);

handle_info(reconnect, #state{clientid = ClientId, opts = Opts} = State) ->
    case do_connect(ClientId, Opts) of
        {ok, Pid, _} ->
            Topics = State#state.topics,
            [do_subscribe(Topic, SubOpts, State#state{client = Pid}) || {Topic, SubOpts} <- Topics],
            {noreply, State#state{client = Pid}};
        {error, Reason} ->
            logger:error("MQTT Client ~p stop, ~p~n", [ClientId, Reason]),
            erlang:send_after(5000, self(), reconnect),
            {noreply, State#state{client = undefined}}
    end;

handle_info(Info, State = #state{}) ->
    logger:error("unexpected msg ~p, ~p~n", [Info, State]),
    {noreply, State}.

terminate(Reason, State = #state{ clientid = ClientId, mod = Mod }) ->
    Mod:stop(Reason, ClientId, State#state.child_state),
    ok.

code_change(_OldVsn, State = #state{}, _Extra) ->
    {ok, State}.


do_connect(ClientId, Opts) ->
    case emqtt:start_link([{owner, self()},{clientid, ClientId} | Opts]) of
        {ok, ConnPid} ->
            case emqtt:connect(ConnPid) of
                {ok, Properties} ->
                    {ok, ConnPid, Properties};
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

do_subscribe(Topic, SubOpts, #state{topics = OldTopics} = State) ->
    case emqtt:subscribe(State#state.client, Topic, SubOpts) of
        {ok, Properties, ReasonCode} ->
            Topics1 = [{Topic, SubOpts} | OldTopics],
            {ok, Properties, ReasonCode, State#state{topics = Topics1}};
        {error, Reason} ->
            {error, Reason}
    end.