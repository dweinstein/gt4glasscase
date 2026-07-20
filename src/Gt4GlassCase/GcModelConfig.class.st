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

{ #category : 'accessing' }
GcModelConfig >> atAny: anArrayOfKeys [
	"First present value among alternative config keys (model families name the same field differently)."
	anArrayOfKeys do: [ :k | (rawJson at: k ifAbsent: [ nil ]) ifNotNil: [ :v | ^ v ] ].
	^ nil
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
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | (v isCollection and: [ v isString not ]) ifTrue: [ v printString ] ifFalse: [ v displayString ] ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'typed accessors' }
GcModelConfig >> hiddenSize [
	^ self atAny: #('hidden_size' 'n_embd' 'd_model')
]

{ #category : 'typed accessors' }
GcModelConfig >> intermediateSize [
	^ self atAny: #('intermediate_size' 'n_inner' 'ffn_dim')
]

{ #category : 'typed accessors' }
GcModelConfig >> kvHeads [
	^ self atAny: #('num_key_value_heads' 'num_kv_heads')
]

{ #category : 'typed accessors' }
GcModelConfig >> modelType [
	^ self at: 'model_type'
]

{ #category : 'accessing' }
GcModelConfig >> numExperts [
	"MoE expert count under whichever key the model family uses; nil for dense models."
	^ self atAny: #('num_experts' 'num_local_experts' 'n_routed_experts' 'moe_num_experts')
]

{ #category : 'typed accessors' }
GcModelConfig >> numHeads [
	^ self atAny: #('num_attention_heads' 'n_head')
]

{ #category : 'typed accessors' }
GcModelConfig >> numLayers [
	^ self atAny: #('num_hidden_layers' 'n_layer' 'num_layers')
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
	^ self atAny: #('vocab_size')
]
