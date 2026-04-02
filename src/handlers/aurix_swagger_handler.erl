-module(aurix_swagger_handler).

-export([init/2]).

init(Req0, #{action := Action} = State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            handle(Action, Req0, State);
        _ ->
            Req = cowboy_req:reply(405, #{<<"content-type">> => <<"application/json">>},
                jsx:encode(#{<<"error">> => #{
                    <<"code">> => <<"method_not_allowed">>,
                    <<"message">> => <<"Only GET is supported">>,
                    <<"details">> => #{}
                }}), Req0),
            {ok, Req, State}
    end.

handle(ui, Req0, State) ->
    Html = swagger_ui_html(),
    Req = cowboy_req:reply(200, #{<<"content-type">> => <<"text/html">>}, Html, Req0),
    {ok, Req, State};

handle(spec, Req0, State) ->
    PrivDir = code:priv_dir(aurix),
    SpecFile = filename:join([PrivDir, "swagger", "openapi.json"]),
    case file:read_file(SpecFile) of
        {ok, Bin} ->
            Req = cowboy_req:reply(200, #{
                <<"content-type">> => <<"application/json">>,
                <<"access-control-allow-origin">> => <<"*">>
            }, Bin, Req0),
            {ok, Req, State};
        {error, _} ->
            Req = cowboy_req:reply(500, #{<<"content-type">> => <<"application/json">>},
                jsx:encode(#{<<"error">> => #{
                    <<"code">> => <<"internal_error">>,
                    <<"message">> => <<"Spec file not found">>,
                    <<"details">> => #{}
                }}), Req0),
            {ok, Req, State}
    end.

swagger_ui_html() ->
    <<"<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Aurix API — Swagger</title>
    <link rel=\"stylesheet\" href=\"https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui.css\" />
</head>
<body>
    <div id=\"swagger-ui\"></div>
    <script src=\"https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui-bundle.js\"></script>
    <script>
        SwaggerUIBundle({
            url: '/swagger/spec',
            dom_id: '#swagger-ui',
            presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
            layout: 'BaseLayout',
            deepLinking: true
        });
    </script>
</body>
</html>">>.
