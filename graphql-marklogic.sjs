/*
 * Module which interfaces with Ruben Taelman's JavaScript libraries
 * 
 * Version: 1.0.0
 * Author: Charles Foster
 * 
 * Copyright 2019 XML London Limited. All rights reserved.
 *  
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *  
 *     http://www.apache.org/licenses/LICENSE-2.0
 *  
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
var graphqlToSparql = require("lib/graphql-to-sparql.js");
var sparqlAlgebra = require("lib/sparqlalgebrajs.js");
var sparqlJsonToTree = require("lib/sparqljson-to-tree.js");
var sem = require("/MarkLogic/semantics.xqy");

// ---------- The following variable is injected in from XQRS ------------
var pObject;
pObject = JSON.parse(pObject);
// -----------------------------------------------------------------------

/* GraphQL Query as a String */
var pQuery = pObject["query"];

/* GraphQL Config JSON Object */
var pConfig = pObject["config"];

/* alternative behaviour "sparql-results", "show-sparql-query" */
var pAction = pObject["action"];

var context = pConfig["context"];
var schema = pConfig["schema"];
var materializeRdfJsTermsOption = pConfig["materializeRdfJsTerms"];

/** Converts GraphQL to SPARQL **/
function graphql2sparql(query, context) {
  var algebra =
    new graphqlToSparql.Converter().graphqlToSparqlAlgebra(query, context);
  return sparqlAlgebra.toSparql(algebra);
}

/** Execute SPARQL Query, results come back as SPARQL Results JSON **/
function executeSparql(sparqlQuery) {   
  return sem.queryResultsSerialize(sem.sparql(sparqlQuery), "json");
}

/** Converts SPARQL Results to a JSON Tree **/
function toJSONTree(
  sparqlJsonResults,
  materializeRdfJsTermsOption,
  schema) {
  var resultsToTreeConverter = new sparqlJsonToTree.Converter(
  {
    // The string to split variable names by. (Default: '_')
    delimiter: "_",
    // If terms should be converted to their raw value instead
    // of being represented as RDFJS terms (Default: false)
    materializeRdfJsTerms: materializeRdfJsTermsOption
  });
    
  return (
    resultsToTreeConverter.sparqlJsonResultsToTree(sparqlJsonResults, schema)
  );
}

var sparqlQuery = sparqlQuery = graphql2sparql(pQuery, context);

if(pAction == "show-sparql-query")
{
  // Just show the SPARQL Query Generated (for debugging purposes)
  sparqlQuery;
}
else
{
  // Execute the Query and produce the result
  var sparqlJSONResults = JSON.parse(executeSparql(sparqlQuery));
  
  if(pAction == "sparql-results")
  { 
    // Produce SPARQL JSON Results
    sparqlJSONResults;
  }
  else // (DEFAULT BEHAVIOUR)
  {
    // Produce GraphQL Result JSON
    toJSONTree(
      sparqlJSONResults,
      materializeRdfJsTermsOption,
      schema
    );
  }
}
