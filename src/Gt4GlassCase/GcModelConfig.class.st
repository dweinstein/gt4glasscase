"
Typed accessors over config.json; the raw JSON is always retained.
"
Class {
	#name : 'GcModelConfig',
	#superclass : 'Object',
	#instVars : [
		'rawJson'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcModelConfig class >> fromDictionary: aDictionary [
	^ self new rawJson: aDictionary; yourself
]

{ #category : 'converting' }
GcModelConfig >> architecture [
	^ GcArchitecture fromConfig: self
]

{ #category : 'accessing' }
GcModelConfig >> at: aKey [
	^ rawJson at: aKey ifAbsent: [ nil ]
]

{ #category : 'views' }
GcModelConfig >> gtArchitectureFor: aView [
	"The derived shape -- composed from the same config."
	<gtView>
	^ aView forward
		title: 'Architecture';
		priority: 2;
		object: [ self architecture ];
		view: #gtOverviewFor:
]

{ #category : 'views' }
GcModelConfig >> gtConfigFor: aView [
	"What does this model declare in config.json?"
	<gtView>
	^ aView columnedList
		title: 'Config';
		priority: 1;
		items: [ rawJson
			ifNil: [ #() ]
			ifNotNil: [ rawJson associations asSortedCollection: [ :a :b | a key < b key ] ] ];
		column: 'Key' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value printString ]
]

{ #category : 'typed accessors' }
GcModelConfig >> hiddenSize [
	^ self at: 'hidden_size'
]

{ #category : 'typed accessors' }
GcModelConfig >> intermediateSize [
	^ self at: 'intermediate_size'
]

{ #category : 'typed accessors' }
GcModelConfig >> kvHeads [
	^ self at: 'num_key_value_heads'
]

{ #category : 'typed accessors' }
GcModelConfig >> modelType [
	^ self at: 'model_type'
]

{ #category : 'typed accessors' }
GcModelConfig >> numHeads [
	^ self at: 'num_attention_heads'
]

{ #category : 'typed accessors' }
GcModelConfig >> numLayers [
	^ self at: 'num_hidden_layers'
]

{ #category : 'printing' }
GcModelConfig >> printOn: aStream [
	aStream nextPutAll: 'GcModelConfig('.
	aStream nextPutAll: (self modelType ifNil: [ '?' ]) asString.
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcModelConfig >> rawJson [
	^ rawJson
]

{ #category : 'accessing' }
GcModelConfig >> rawJson: aDictionary [
	rawJson := aDictionary
]

{ #category : 'typed accessors' }
GcModelConfig >> vocabSize [
	^ self at: 'vocab_size'
]
