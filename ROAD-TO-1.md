# The road to TSNREST 1.0

## Goals
TSNREST is ment to be a drop-in library for communicating with REST APIs. It will be highly configurable and easily extendible.

It will take the good parts from Ember Data, while maintaining the advantages of being built on Core Data and MagicalRecord.

## 0.4.0
For 0.4.0 we'll start working towards the goals staded above. The first major change will be splitting categories into specific features, instead of being <objectType>+TSNRESTAdditions. Currently, many of the files have become too large for comfort.

## Blocking bugs and missing features
* ~~Fix loading retain bugs by refactoring all requests to a custom subclass or object~~
* Support custom serializers and deserializers instead of mappingBlocks and reverseMappingBlocks
* ~~Refactor global settings into a separate object, like in WKWebView~~
* support ?fields and saving fields (`[object saveFields:@[…]]`)
* ~~Settings for camelCase and snake_case, and automatic switcing between them
* Automatic mapping, with TSNRestObjectMap only handling edge-cases~~
* Don't require special core data fields (dirty, systemId) unless persisting from session to session
* Support (de)serializing all types of relations (many-relations as well) automatically
