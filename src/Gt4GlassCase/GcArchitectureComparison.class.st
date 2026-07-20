"
A side-by-side comparison of several labeled GcArchitectures (label -> architecture associations): rows are architecture facets, one column per model, differences marked. Instantly exposes a 'finetune' that is secretly a different architecture.
"
Class {
	#name : 'GcArchitectureComparison',
	#superclass : 'Object',
	#instVars : [
		'labeledArchitectures'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcArchitectureComparison class >> forAll: aCollectionOfAssociations [
	^ self new
		labeledArchitectures: aCollectionOfAssociations asOrderedCollection;
		yourself
]

{ #category : 'accessing' }
GcArchitectureComparison >> architectures [
	^ (labeledArchitectures collect: [ :each | each value ]) asArray
]

{ #category : 'accessing' }
GcArchitectureComparison >> facetRows [
	| facets |
	facets := OrderedCollection new.
	facets add: 'Layers' -> #numLayers.
	facets add: 'Attention heads' -> #numHeads.
	facets add: 'KV heads (GQA)' -> #kvHeads.
	facets add: 'Hidden size' -> #hiddenSize.
	facets add: 'Head dim' -> #headDim.
	facets add: 'MoE experts' -> #moeExperts.
	^ (facets collect: [ :facet |
		| selector values allSame |
		selector := facet value.
		values := self architectures collect: [ :architecture |
			architecture isNil ifTrue: [ nil ] ifFalse: [ architecture perform: selector ] ].
		allSame := (values reject: [ :v | v isNil ]) asSet size <= 1.
		{ facet key. values. allSame } ]) asArray
]

{ #category : 'views' }
GcArchitectureComparison >> gtFacetGridFor: aView [
	<gtView>
	"How does this model's architecture differ from its declared siblings and ancestors?"
	| list |
	(labeledArchitectures isNil or: [ labeledArchitectures isEmpty ])
		ifTrue: [ ^ aView empty ].
	list := aView columnedList
		title: 'Architecture compare';
		priority: 1;
		items: [ self facetRows ];
		column: 'Facet' text: [ :row | (row at: 3) ifTrue: [ row at: 1 ] ifFalse: [ '<> ' , (row at: 1) ] ];
		yourself.
	self labels doWithIndex: [ :label :i |
		list column: label text: [ :row | ((row at: 2) at: i) ifNil: [ '-' ] ifNotNil: [ :v | v displayString ] ] ].
	^ list
]

{ #category : 'views' }
GcArchitectureComparison >> gtModelsFor: aView [
	<gtView>
	"Which models are being compared?"
	^ aView columnedList
		title: 'Models';
		priority: 2;
		items: [ labeledArchitectures ];
		column: 'Model' text: [ :assoc | assoc key ];
		column: 'Architecture' text: [ :assoc | assoc value printString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'accessing' }
GcArchitectureComparison >> labeledArchitectures [
	^ labeledArchitectures
]

{ #category : 'accessing' }
GcArchitectureComparison >> labeledArchitectures: aCollection [
	labeledArchitectures := aCollection
]

{ #category : 'accessing' }
GcArchitectureComparison >> labels [
	^ (labeledArchitectures collect: [ :each | each key ]) asArray
]

{ #category : 'printing' }
GcArchitectureComparison >> printOn: aStream [
	aStream
		nextPutAll: 'architecture comparison of ';
		print: (labeledArchitectures ifNil: [ 0 ] ifNotNil: [ :collection | collection size ]);
		nextPutAll: ' models'
]
