#!/bin/sh
./rebar get-deps compile
erl -pa ebin -pa deps/*/ebin
