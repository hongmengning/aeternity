-module(aeu_lager_logger_handler).

-export([
          adding_handler/1
        , changing_config/3
        , filter_config/1
        , log/2
        , removing_handler/1
        ]).

-include_lib("kernel/include/logger.hrl").

-spec adding_handler(Config) -> {ok, map()} | {error,Reason} when
      Config :: logger:handler_config(),
      Reason :: term().
adding_handler(Config) ->
    {ok, Config#{ filters => []
                , level => debug
                , filter_default => log}}.

%%% Log a string or report
-spec log(LogEvent, Config) -> ok when
      LogEvent :: logger:log_event(),
      Config :: logger:handler_config().
log(#{msg := {Tag, _}}, _Cfg) when is_atom(Tag) ->
    ok;
log(#{level := Level, msg := Msg} = Event, _Cfg) ->
    {Fmt, Args} = case Msg of
                      {F, _} = FA when is_list(F) -> FA;
                      Str when is_list(Str) ->
                          {Str, []};
                      Other ->
                          {"~p", [Other]}
                  end,
    Meta = metadata(Event),
    lager_log(Level, Meta, Fmt, Args);
    %% lager:log(Level, Meta, Fmt, Args);
log(_, _) ->
    ok.

%%% Updating handler config
-spec changing_config(SetOrUpdate, OldConfig, NewConfig) ->
                              {ok,Config} | {error,Reason} when
      SetOrUpdate :: set | update,
      OldConfig :: logger:handler_config(),
      NewConfig :: logger:handler_config(),
      Config :: logger:handler_config(),
      Reason :: term().
changing_config(_SetOrUpdate, _OldConfig, NewConfig) ->
    {ok, NewConfig}.

%%% Remove internal fields from configuration
-spec filter_config(Config) -> Config when
      Config :: logger:handler_config().
filter_config(Config) ->
    Config.

%%% Handler being removed
-spec removing_handler(Config) -> ok when
      Config :: logger:handler_config().
removing_handler(_Config) ->
    ok.

metadata(#{ meta := #{ mfa  := {M, F, _A}
                     , line := Line
                     , pid  := Pid } }) ->
    [ {module, M}
    , {function, F}
    , {line, Line}
    , {pid, Pid}
    , {node, node()} | lager:md() ];
metadata(#{ meta := #{pid := Pid} }) ->
    [{pid, Pid} | lager:md()];
metadata(_) ->
    [{pid, self()} | lager:md()].

lager_log(Level, Meta, Fmt, Args) ->
    LevelNum = lager_util:level_to_num(Level),
    case {whereis(lager_event), lager_config:get({lager_event, loglevel}, {0, []})} of
        {undefined, _} ->
            {error, lager_not_running};
        {Pid, {LogLevel, Traces}} when LogLevel band LevelNum =/= 0;
                                       Traces =/= [] ->
            lager:do_log(Level, Meta, Fmt, Args, size(), LevelNum,
                         LogLevel, Traces, lager_event, Pid)
    end.

%% This is the typical truncation size generated by lager_transform
size() -> 4096.
