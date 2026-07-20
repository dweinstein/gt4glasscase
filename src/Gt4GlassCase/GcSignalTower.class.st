"
One SEGMENT of a checkpoint's computation graph identified purely from tensor names: a stack of transformer-style layers sharing a common tower key (the path up to and including the layer word: layers / h / blocks / block). Examples of towers: the main language tower (model.language_model.layers.* or model.layers.* or transformer.h.*), a vision tower (model.visual.blocks.*), an audio tower. Each tower discovers its own DISTINCT ARCHETYPES (GcSignalArchetype) -- groups of layers whose per-layer module set is identical -- so a heterogeneous stack (e.g. mixed linear-attention / full-attention / MoE layers) is told honestly as several archetype blocks rather than one fictional union block. role is #main for the tower that carries the token stream to the head (heuristically the tower with the most layers, tie-broken away from vision/audio), otherwise #auxiliary (rendered as its own labelled strand). Holds only GcTensorRefs (never weights, I5).
"
Class {
	#name : 'GcSignalTower',
	#superclass : 'Object',
	#instVars : [
		'flow',
		'key',
		'layerWord',
		'prefix',
		'name',
		'role',
		'tensors',
		'archetypes'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcSignalTower class >> flow: aFlow key: aString tensors: aGroup [
	^ self new setFlow: aFlow key: aString tensors: aGroup
]

{ #category : 'accessing' }
GcSignalTower >> archetypeCount [
	^ archetypes size
]

{ #category : 'accessing' }
GcSignalTower >> archetypes [
	^ archetypes
]

{ #category : 'initialization' }
GcSignalTower >> deriveNaming [
	"Split the tower key (e.g. 'model.language_model.layers') into its layer word and prefix, and pick a friendly name + default role. Recognised keywords name vision/audio/language/text towers; otherwise the tower is named after the last component of its prefix (e.g. 'mtp'), or 'main' for a plain root prefix (model / transformer / gpt_neox / decoder / backbone / empty)."
	| parts lower last |
	parts := key substrings: '.'.
	layerWord := parts isEmpty ifTrue: [ key ] ifFalse: [ parts last ].
	prefix := parts size <= 1 ifTrue: [ '' ] ifFalse: [ '.' join: parts allButLast ].
	lower := key asLowercase.
	((lower includesSubstring: 'visual') or: [ lower includesSubstring: 'vision' ])
		ifTrue: [ name := 'vision'. role := #auxiliary. ^ self ].
	(lower includesSubstring: 'audio')
		ifTrue: [ name := 'audio'. role := #auxiliary. ^ self ].
	(lower includesSubstring: 'language_model')
		ifTrue: [ name := 'language'. role := #main. ^ self ].
	(lower includesSubstring: 'text_model')
		ifTrue: [ name := 'text'. role := #main. ^ self ].
	last := prefix isEmpty ifTrue: [ '' ] ifFalse: [ (prefix substrings: '.') last ].
	(prefix isEmpty or: [ #('model' 'transformer' 'gpt_neox' 'decoder' 'backbone') includes: last ])
		ifTrue: [ name := 'main'. role := #main. ^ self ].
	name := last.
	role := #main
]

{ #category : 'derivation' }
GcSignalTower >> detectArchetypes [
	"Group this tower's layer indices into archetypes: layers whose per-layer module signature set is identical share an archetype."
	| byIndex bySig |
	byIndex := Dictionary new.
	tensors do: [ :t | | idx |
		idx := t layerIndex.
		idx ifNotNil: [ (byIndex at: idx ifAbsentPut: [ Set new ]) add: (flow signatureOf: t) ] ].
	bySig := Dictionary new.
	(byIndex keys asSortedCollection) do: [ :idx | | sigKey |
		sigKey := (byIndex at: idx) asSortedCollection asArray.
		(bySig at: sigKey ifAbsentPut: [ OrderedCollection new ]) add: idx ].
	archetypes := (bySig values collect: [ :indices | GcSignalArchetype tower: self layerIndices: indices ])
		asSortedCollection: [ :a :b | a firstLayer < b firstLayer ].
	archetypes := archetypes asArray
]

{ #category : 'accessing' }
GcSignalTower >> firstArchetype [
	^ archetypes isEmpty ifTrue: [ nil ] ifFalse: [ archetypes first ]
]

{ #category : 'accessing' }
GcSignalTower >> flow [
	^ flow
]

{ #category : 'views' }
GcSignalTower >> gtArchetypesFor: aView [
	"The distinct kinds of layer in this tower -- one row per archetype; click one to inspect its layers and modules."
	<gtView>
	^ aView columnedList
		title: 'Archetypes';
		priority: 1;
		items: [ archetypes ];
		column: 'Layers' text: [ :a | a badgeString ];
		column: 'Attention' text: [ :a | a attentionKindLabel ];
		column: 'MLP' text: [ :a | a mlpKindLabel ];
		send: [ :a | a ]
]

{ #category : 'views' }
GcSignalTower >> gtTensorsFor: aView [
	"Every tensor in this tower."
	<gtView>
	^ aView forward
		title: 'Tensors';
		priority: 2;
		object: [ tensors ];
		view: #gtShapeTableFor:
]

{ #category : 'testing' }
GcSignalTower >> isAuxiliary [
	^ role ~= #main
]

{ #category : 'testing' }
GcSignalTower >> isMain [
	^ role = #main
]

{ #category : 'accessing' }
GcSignalTower >> key [
	^ key
]

{ #category : 'accessing' }
GcSignalTower >> layerCount [
	^ tensors layerIndices size
]

{ #category : 'accessing' }
GcSignalTower >> layerWord [
	^ layerWord
]

{ #category : 'accessing' }
GcSignalTower >> name [
	^ name
]

{ #category : 'accessing' }
GcSignalTower >> prefix [
	^ prefix
]

{ #category : 'printing' }
GcSignalTower >> printOn: aStream [
	aStream
		nextPutAll: 'GcSignalTower(';
		nextPutAll: (name ifNil: [ key ]);
		nextPutAll: ', ';
		nextPutAll: self summaryString;
		nextPut: $)
]

{ #category : 'accessing' }
GcSignalTower >> role [
	^ role
]

{ #category : 'accessing' }
GcSignalTower >> role: aSymbol [
	role := aSymbol
]

{ #category : 'initialization' }
GcSignalTower >> setFlow: aFlow key: aString tensors: aGroup [
	flow := aFlow.
	key := aString.
	tensors := aGroup.
	self deriveNaming.
	self detectArchetypes
]

{ #category : 'printing' }
GcSignalTower >> summaryString [
	"e.g. '3 archetypes / 40 layers' or '1 archetype / 30 layers'."
	| a |
	a := self archetypeCount.
	^ a printString , ' archetype' , (a = 1 ifTrue: [ '' ] ifFalse: [ 's' ])
		, ' / ' , self layerCount printString , ' layers'
]

{ #category : 'accessing' }
GcSignalTower >> tensors [
	^ tensors
]
