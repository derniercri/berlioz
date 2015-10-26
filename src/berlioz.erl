%% Berlioz : a concurrent file reader

%% Copyright (c) <2015> <Pierre Ruyter>
%% Copyright (c) <2015> <Xavier Van de Woestyne>
%% Copyright (c) <2007> <Per Gustafsson> for bit tech
%% Copyright (c) <2015> <derniercri.io>

%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:

%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.

-module(berlioz).

-export([
         open/1,
         lines_of/1, 
         close/1,
         bitstream/1, 
         deflate/1, 
         to_string/1
        ]).

-compile([native]).
-include("berlioz_macro.hrl").


monitor(Callback) -> erlang:spawn_monitor(Callback).
fault(Atom) -> erlang:error(Atom).
open(Path) -> monitor(fun() -> start(Path) end).
wrap_binary(Prefix, [Head|Tail]) -> [<<Prefix/binary, Head/binary>>|Tail].

sub(Binaries) -> sub(Binaries, 0, []).
sub(Binaries, Size, Acc) ->
    case Binaries of 
        <<_:Size/binary,10,_/binary>> -> 
            <<Head:Size/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,10,_/binary>> ->
            Offset = Size + 1,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,_,10,_/binary>> ->
            Offset = Size + 2,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,_,_,10,_/binary>> ->
            Offset = Size + 3,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,_,_,_,10,_/binary>> ->
            Offset = Size + 4,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,_,_,_,_,10,_/binary>> ->
            Offset = Size + 5,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,_,_,_,_,_,10,_/binary>> ->
            Offset = Size + 6,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,_,_,_,_,_,_,10,_/binary>> ->
            Offset = Size + 7,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,_,_,_,_,_,_,_,10,_/binary>> ->
            Offset = Size + 8,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_,_,_,_,_,_,_,_,_,10,_/binary>> ->
            Offset = Size + 9,
            <<Head:Offset/binary,_,Tail/binary>> = Binaries,
            sub(Tail, 0, [ Head | Acc ]);
        <<_:Size/binary,_:80,_/binary>> -> sub(Binaries, Size+10, Acc);
        <<_:Size/binary,_,_/binary>> -> sub(Binaries, Size+1, Acc);
        _ -> lists:reverse([Binaries|Acc])
    end.


close({Pid, _}) -> Pid ! stop.
start(Path) ->   
    {ok, File} = file:open(Path, [raw, binary]),
    treat_lines(File, <<>>).
                    

lines_of({Pid, Reference}) ->
    Pid ! {lines_of, Reference, self()},
    receive
        {{Data, Prefix}, Reference} ->
            case sub(Data) of 
                [ Head | Tail ] -> wrap_binary(Prefix, [ Head | Tail ]);
                [ ] -> [ Prefix ]
            end;
        {eof, Reference} -> eof;
        {'DOWN', Reference, _, Pid, _} -> fault(close_file)
    end.

deflate(Binaries) ->
    lists:foldl(
      fun(Elt, Acc) -> <<Acc/binary, Elt/binary>> end,
      << >>, 
      Binaries
     ).

to_string(IoDevice) ->
    L = lines_of(IoDevice),
    binary_to_list(deflate(L)).

bitstream({Pid, Reference}) ->
    Pid ! {char_of, Reference, self()},
    receive
        {{Data, _Prefix}, Reference} -> 
            lists:foldl(
              fun(X, SUM) -> <<SUM/binary, X/binary>> end, 
              <<>>, Data
             );
        {eof, Reference} -> eof;
        {'DOWN', Reference, _, Pid, _} -> fault(close_file)
    end.


last_line_of(Binaries) -> last_nl_of(Binaries, size(Binaries)-1).
last_nl_of(Binaries, Size) ->
    io:format("pie~n"),
    case Binaries of 
        <<Lines:Size/binary, 10, Acc/binary>> -> {Lines, Acc};
        _ -> if Size =< 0 -> Binaries;
                true -> last_nl_of(Binaries, Size - 1)
             end
    end.

process_lines(File, Acc) ->
    case file:read(File, ?LARGE_BUFFER_SIZE) of 
        eof when size(Acc) =:= 0  -> {eof, <<>>};
        eof -> {{<<>>, Acc}, <<>>};
        {ok, Binaries} ->
            case last_line_of(Binaries) of 
                {Lines, AccR} -> {{Lines, Acc}, AccR};
                AccR -> process_lines(File, <<Acc/binary, AccR/binary>>)
            end
    end.

treat_lines(File, Acc) ->
    {Data, AccR} = process_lines(File, Acc),
    receive
        {lines_of, Reference, Pid} -> 
            Pid ! {Data, Reference},
            treat_lines(File, AccR);
        {char_of, Reference, Pid} ->
            Pid ! {Data, Reference},
            treat_lines(File, AccR);
        stop -> file:close(File)
    end.
