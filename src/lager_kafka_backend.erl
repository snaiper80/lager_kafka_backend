%% Copyright (c) 2014 by snaiper(snaiper80 at gmail.com). All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
-module(lager_kafka_backend).
-behaviour(gen_event).

-include_lib("lager/include/lager.hrl").

-export([
    init/1,
    handle_call/2,
    handle_event/2,
    handle_info/2,
    terminate/2,
    code_change/3,
    test/0
]).

-define(DEFAULT_BROKER,           {"localhost", 9092}).
-define(DEFAULT_SENDMETHOD,       async).
-define(DEFAULT_FORMATTER,        lager_default_formatter).
-define(DEFAULT_FORMATTER_CONFIG, []).

-record(state, {
    id               :: tuple(),
    level            :: integer(),
    topic            :: binary(),
    method           :: atom(),
    formatter        :: atom(),
    formatter_config :: any()
}).

%% ===================================================================
%% Public
%% ===================================================================
init(Params) ->
    Level        = config_val(level,            Params, debug),
    Topic        = config_val(topic,            Params, list_to_binary(atom_to_list(?MODULE))),
    Broker       = config_val(broker,           Params, ?DEFAULT_BROKER),
    Method       = config_val(send_method,      Params, ?DEFAULT_SENDMETHOD),
    Formatter    = config_val(formatter,        Params, ?DEFAULT_FORMATTER),
    FormatConfig = config_val(formatter_config, Params, ?DEFAULT_FORMATTER_CONFIG),

    % ekaf optional parameter
    [begin
        case atom_to_list(K) of
            [$e, $k, $a, $f | _] ->
                application:set_env(ekaf, K, V);
            _ ->
                ok
        end
     end || {K, V} <- Params],

    % Set env variables
    application:set_env(ekaf, ekaf_bootstrap_broker, Broker),
    application:set_env(ekaf, ekaf_bootstrap_topics, Topic),

    % Prepare for topic
    ekaf:prepare(Topic),

    {ok, #state{
        id               = {?MODULE, Topic},
        level            = lager_util:level_to_num(Level),
        topic            = Topic,
        method           = Method,
        formatter        = Formatter,
        formatter_config = FormatConfig
    }}.

handle_call({set_loglevel, Level}, State) ->
    try parse_level(Level) of
        Lvl ->
            {ok, ok, State#state{ level = Lvl}}
    catch
        _:_ ->
            {ok, {error, bad_log_level}, State}
    end;
handle_call(get_loglevel, #state{ level = Level } = State) ->
    {ok, Level, State};
handle_call(_Request, State) ->
    {ok, ok, State}.

handle_event({log, Message}, #state{ id = Id, level = L, formatter = Formatter, formatter_config = FormatConfig } = State) ->
    case lager_util:is_loggable(Message, L, Id) of
        true ->
            log(Formatter:format(Message, FormatConfig), State),
            {ok, State};
        false ->
            {ok, State}
    end;
handle_event(_Event, State) ->
    {ok, State}.


handle_info(_Info, State) ->
  {ok, State}.


terminate(_Reason, _State) ->
  ok.


code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%% ===================================================================
%% Private
%% ===================================================================
log(Msg, #state{ topic = Topic, method = async } = State) ->
    Output = unicode:characters_to_binary(Msg),
    ok = ekaf:produce_async(Topic, Output),
    State;
log(Msg, #state{ topic = Topic, method = sync } = State) ->
    Output = unicode:characters_to_binary(Msg),
    ekaf:produce_sync(Topic, Output),
    State.

config_val(C, Params, Default) ->
    case lists:keyfind(C, 1, Params) of
        {C, V} -> V;
        _ -> Default
    end.

parse_level(Level) ->
    try lager_util:config_to_mask(Level) of
        Res ->
            Res
    catch
        error:undef ->
            %% must be lager < 2.0
            lager_util:level_to_num(Level)
    end.

%% ===================================================================
%% Test
%% ===================================================================

test() ->
    application:set_env(lager, handlers, [
        {lager_console_backend, debug},
        {lager_kafka_backend, [
                {level,                      info},
                {topic,                      <<"test">>},
                {broker,                     {"localhost", 9092}},
                {send_method,                async},
                {formatter,                  ?DEFAULT_FORMATTER},
                {formatter_config,           [date, " ", time, " ", message]},
                {ekaf_partition_strategy,    random},
                {ekaf_per_partition_workers, 5}
            ]
        }
      ]),
    application:set_env(lager, error_logger_redirect, false),

    {ok, _} = application:ensure_all_started(ekaf),
    {ok, _} = application:ensure_all_started(lager),

    lager:log(info,  self(), "Test INFO message"),
    lager:log(debug, self(), "Test DEBUG message"),
    lager:log(error, self(), "Test ERROR message").
