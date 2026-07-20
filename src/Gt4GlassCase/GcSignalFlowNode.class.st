"
One block in a GcSignalFlow diagram: a labelled node with a kind (#tokens #embedding #norm #attention #mlp #add #finalNorm #head #output #legend), an optional dimension annotation, an optional badge (e.g. 'x N layers'), and forward + residual successor nodes (object references, not associations) used to draw the signal path and the residual bypass edges. When tensors are loaded a module node carries its cross-layer cohort as its payload (a GcTensorGroup); clicking it reaches that cohort's own skyline/stats views. No node is dead -- structural nodes still answer a details view.
"
Class {
	#name : 'GcSignalFlowNode',
	#superclass : 'Object',
	#instVars : [
		'label',
		'kind',
		'payload',
		'annotation',
		'forwardTargets',
		'residualTargets',
		'badge'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'building' }
GcSignalFlowNode >> addForward: aNode [
	forwardTargets add: aNode
]

{ #category : 'building' }
GcSignalFlowNode >> addResidual: aNode [
	residualTargets add: aNode
]

{ #category : 'accessing' }
GcSignalFlowNode >> annotation [
	^ annotation
]

{ #category : 'accessing' }
GcSignalFlowNode >> annotation: aStringOrNil [
	annotation := aStringOrNil
]

{ #category : 'accessing' }
GcSignalFlowNode >> badge [
	^ badge
]

{ #category : 'accessing' }
GcSignalFlowNode >> badge: aStringOrNil [
	badge := aStringOrNil
]

{ #category : 'accessing' }
GcSignalFlowNode >> detailFacets [
	^ {
		'Stage' -> label.
		'Kind' -> kind.
		'Annotation' -> (annotation ifNil: [ '-' ]).
		'Badge' -> (badge ifNil: [ '-' ]).
		'Forward to' -> (forwardTargets isEmpty ifTrue: [ '-' ] ifFalse: [ ', ' join: (forwardTargets collect: [ :n | n label ]) ]).
		'Residual to' -> (residualTargets isEmpty ifTrue: [ '-' ] ifFalse: [ ', ' join: (residualTargets collect: [ :n | n label ]) ]) }
]

{ #category : 'accessing' }
GcSignalFlowNode >> forwardTargets [
	^ forwardTargets
]

{ #category : 'gt views' }
GcSignalFlowNode >> gtDetailsFor: aView [
	"What is this block, and where does its signal go?"
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 2;
		items: [ self detailFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | v displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt views' }
GcSignalFlowNode >> gtWeightsFor: aView [
	"The real weights behind this block: its cross-layer cohort (or the config facet, for an inferred diagram)."
	<gtView>
	| selector |
	selector := self payloadViewSelector.
	(payload notNil and: [ selector notNil ]) ifFalse: [ ^ self gtDetailsFor: aView ].
	^ aView forward
		title: 'Weights';
		priority: 1;
		object: [ payload ];
		view: selector
]

{ #category : 'initialization' }
GcSignalFlowNode >> initialize [
	super initialize.
	forwardTargets := OrderedCollection new.
	residualTargets := OrderedCollection new
]

{ #category : 'testing' }
GcSignalFlowNode >> isModule [
	^ #(attention mlp norm embedding finalNorm head tower auxHead) includes: kind
]

{ #category : 'accessing' }
GcSignalFlowNode >> kind [
	^ kind
]

{ #category : 'accessing' }
GcSignalFlowNode >> kind: aSymbol [
	kind := aSymbol
]

{ #category : 'accessing' }
GcSignalFlowNode >> label [
	^ label
]

{ #category : 'accessing' }
GcSignalFlowNode >> label: aString [
	label := aString
]

{ #category : 'accessing' }
GcSignalFlowNode >> payload [
	^ payload
]

{ #category : 'accessing' }
GcSignalFlowNode >> payload: anObject [
	payload := anObject
]

{ #category : 'views' }
GcSignalFlowNode >> payloadViewSelector [
	payload isNil ifTrue: [ ^ nil ].
	(payload isKindOf: GcTensorGroup) ifTrue: [ ^ #gtShapeTableFor: ].
	(payload isKindOf: GcArchitecture) ifTrue: [ ^ #gtOverviewFor: ].
	(payload isKindOf: GcSignalTower) ifTrue: [ ^ #gtArchetypesFor: ].
	^ nil
]

{ #category : 'printing' }
GcSignalFlowNode >> printOn: aStream [
	aStream nextPutAll: 'GcSignalFlowNode('.
	aStream nextPutAll: (label ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'accessing' }
GcSignalFlowNode >> residualTargets [
	^ residualTargets
]
