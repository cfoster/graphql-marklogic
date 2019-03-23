(:
 : GraphQL endpoint and associated services for MarkLogic Server
 :
 : Turn MarkLogic into a GraphQL Server. GraphQL Queries are translated
 : into SPARQL Queries and then SPARQL Results are converted into
 : GraphQL JSON Result format. 
 :
 : Version: 1.0.0
 : Author: Charles Foster
 :  
 : Copyright 2019 XML London Limited. All rights reserved.
 :  
 : Licensed under the Apache License, Version 2.0 (the "License");
 : you may not use this file except in compliance with the License.
 : You may obtain a copy of the License at
 :  
 :     http://www.apache.org/licenses/LICENSE-2.0
 :  
 : Unless required by applicable law or agreed to in writing, software
 : distributed under the License is distributed on an "AS IS" BASIS,
 : WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 : See the License for the specific language governing permissions and
 : limitations under the License.
 :)

xquery version "1.0-ml";

module namespace graphql = "http://xmllondon.com/xquery/graphql";

declare namespace rest = "http://exquery.org/ns/restxq";

(: Where GraphQL Config files are stored in MarkLogic :)
declare variable $config-path := "/graphql/config/";

(: --------------------- regular /graphql endpoint --------------------- :) 
declare
  %rest:POST("{$query}")
  %rest:path("/graphql")
  %rest:query-param("config", "{$config}")
  %rest:consumes("application/graphql")
function post-graphql($query as xs:string, $config as xs:string?) {
  config($config) => execute($query)
};

declare
  %rest:POST("{$body}")
  %rest:path("/graphql")
  %rest:query-param("config", "{$config}")
  %rest:consumes("application/json")
function post-json($body as document-node(), $config as xs:string?) {
  config($config) => execute($body/query)
};

declare
  %rest:GET
  %rest:path("/graphql")
  %rest:query-param-1("query", "{$query}")
  %rest:query-param-2("config", "{$config}")
function get($query as xs:string, $config as xs:string?) {
  config($config) => execute($query)
};

(: --------------------------------------------------------------------- :)

(: --------------------- /{config}/graphql endpoint -------------------- :)
declare
  %rest:POST("{$query}")
  %rest:path("/{$config}/graphql")
  %rest:consumes("application/graphql")
function config-post-graphql($query as xs:string, $config as xs:string) {
  config($config) => execute($query)
};

declare
  %rest:POST("{$body}")
  %rest:path("/{$config}/graphql")
  %rest:consumes("application/json")
function config-post-json($body as document-node(), $config as xs:string) {
  config($config) => execute($body/query)
};

declare
  %rest:GET
  %rest:path("/{$config}/graphql")
  %rest:query-param("query", "{$query}")
function config-get($query as xs:string, $config as xs:string) {
  config($config) => execute($query)
};
(: --------------------------------------------------------------------- :)

(:~
 : Converts a GraphQL Query into SPARQL 
 : 
 : @param $query the user's GraphQL Query
 : @param $context information helping one convert GraphQL to SPARQL
 : @return a SPARQL Query to inspect and analyse
 :)
declare
  %rest:path("/graphql-to-sparql")
  %rest:query-param-1("query", "{$query}")
  %rest:query-param-2("config", "{$config}")
function graphql-to-sparql($query as xs:string, $config as xs:string) {
  (config($config) => execute($query, "show-sparql-query"))/data
};

declare function execute(
  $config as document-node()?,
  $query as xs:string)
{
  execute($config, $query, "run")
};

declare function execute(
  $config as document-node()?,
  $query as xs:string,
  $action as xs:string)
{
  if(fn:empty($config)) then (
    fn:error("graphql:GRQL0001', 'MarkLogic GraphQL config not set.")
  )
  else (
    invoke-graphql-marklogic-module(
      map:entry("query", $query) =>
      map:with("config", $config) =>
      map:with("action", $action)
    )
  )
};

(:~
 : Invokes the GraphQL MarkLogic Server Side JavaScript XQuery Module
 : 
 : Takes a map as a parameter, which may contain the following keys,
 : "query" (string) a GraphQL Query
 : "config" (document-node) Contains a JSON-LD Context an a GraphQL Schema
 : "materializeRdfJsTerms" (boolean) If terms should be converted to their raw
 :                         value instead of being represented as RDFJS terms
 : "action" (string) set this to "show-sparql-query" to show the generated
 :          SPARQL Query, or "sparql-results" to show the SPARQL JSON Results,
 :          default behaviour being showing a GraphQL JSON Result Tree
 :)
declare
  %private
function invoke-graphql-marklogic-module($map as map:map) {
  try
  {
    if(fn:empty(map:get($map, "config"))) then (
      fn:error("graphql:GRQL0001', 'MarkLogic GraphQL config not set.")
    ) else (
      object-node {
        "data" : 
          xdmp:invoke(
            "graphql-marklogic.sjs", ( xs:QName("pObject"), xdmp:to-json($map)),
            map:entry("isolation", "same-statement")
          ),
        "error" : object-node {} 
      }
    )
  } catch($ex) {
    object-node {
      "data" : object-node { },
      "error" : $ex//*:message/string()
    }
  }
};
(: --------------------------------------------------------------------- :)

(: -------------------------- config endpoints ------------------------- :) 
(:~
 : Inserts a new GraphQL config JSON file in MarkLogic Server
 :)
declare
  %rest:path("/graphql/config/{$uri}")
  %rest:POST("{$body}")
  %rest:PUT("{$body}")
  %rest:consumes("application/json", "text/json")
  %xdmp:update
function insert-config($body as document-node(), $uri as xs:string) {
  xdmp:document-insert($config-path || $uri, $body)
};

(:~
 : Gets a GraphQL config JSON file in MarkLogic Server
 :)
declare
  %rest:path("/graphql/config/{$uri}")
function get-config($uri as xs:string) {
  fn:doc($config-path || $uri)
};

(:~
 : Delete a GraphQL config JSON file in MarkLogic Server
 :)
declare
  %rest:path("/graphql/config/{$uri}")
  %rest:DELETE
  %xdmp:update
function delete-config($uri as xs:string) {
  xdmp:document-delete($config-path || $uri)
};

(:~
 : Lists GraphQL config JSON files in MarkLgic Server
 :)
declare
  %rest:path("/graphql/config")
function list-config() {
  array-node {
    cts:uris((), (), cts:directory-query($config-path)) !
    fn:replace(., '^.*/', '')[normalize-space()]
  }
};

declare function config() as document-node() {
  config('default.json')
};

declare function config($uri as xs:string) as document-node() {
  fn:doc($config-path || $uri)
};

(: --------------------------------------------------------------------- :)

declare
  %rest:path("/test-run")
  %rest:GET
function test-function-2() {
  let $config :=
    document {
      object-node {
        "context" : object-node {
          "me": "http://example.org/me",
          "name": "http://example.org/name",
          "creator" : "http://purl.org/dc/elements/1.1/creator",
          "pname" : "http://xmlns.com/foaf/0.1/name",
          "hero" : "http://example.org/hero",
          "friends" : "http://example.org/friends"
        },
        "schema" : object-node {
          "singularizeVariables" : object-node {
            "" : fn:true(),
            "books": fn:false(),
            "books_name": fn:true()
          }
        },
        "materializeRdfJsTerms" : fn:true()
      }
    }
  return
  invoke-graphql-marklogic-module(
    map:entry("query", "{ creator { pname } }") =>
    map:with("config", $config)
  )
};  
