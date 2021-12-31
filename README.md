# emqtt-client
mqtt client for erlang

## Examples
```erlang
Opts = [
    {host, "127.0.0.1"},
    {port, 1883},
    {username, "112233"},
    {password, "111111"},
    {clientid, <<"client1">>}
],
{ok, Pid} = emqttc:start(?MODULE, Opts),

emqttc:subscribe(Pid, <<"test">>, [{qos, 1}]),

emqttc:publish(Pid, <<"test">>, <<"hello">>, [{qos, 1}]).

```

## License
Apache License Version 2.0
