"
One depth slice of a model: the tensors sharing a transformer layer index, OR a non-layer band (index = nil) holding the embeddings or the head/final tensors. Carries a back-reference to the whole-model GcTensorGroup so its Regularity view can score each tensor against its cross-layer cohort. label answers 'which row is this?'; the Regularity view answers 'does anything at this depth break the model's own texture?'.
"
Class {
	#name : 'GcLayer',
	#superclass : 'Object',
	#instVars : [
		'index',
		'tensors',
		'modelGroup'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcLayer class >> index: anIndexOrNil tensors: aTensorCollection modelGroup: aTensorGroup [
	^ self new
		setIndex: anIndexOrNil tensors: aTensorCollection modelGroup: aTensorGroup
]

{ #category : 'gt - views' }
GcLayer >> gtRegularityFor: aView [
	"How does each tensor in this layer deviate from its same-role cohort across the whole model? Rows are ordered by |z| so an anomaly at this depth surfaces first; click a row to inspect that tensor."
	<gtView>
	^ aView columnedList
		title: 'Regularity';
		priority: 4;
		items: [ (self regularityScores asSortedCollection: [ :a :b | a absZ > b absZ ]) asArray ];
		column: 'Name' text: [ :s | s tensor name ];
		column: 'Module' text: [ :s | s tensor module ifNil: [ '—' ] ];
		column: 'Role' text: [ :s | s tensor parsedName role ifNil: [ '—' ] ];
		column: 'Metric' text: [ :s | s metricLabel ];
		column: 'z' text: [ :s | s zDisplayString ];
		send: [ :s | s tensor ]
]

{ #category : 'gt - views' }
GcLayer >> gtTensorsFor: aView [
	"This layer's tensors as a shape table (forwarded to the tensor sub-group)."
	<gtView>
	^ aView forward
		title: 'Tensors';
		priority: 5;
		object: [ tensors ];
		view: #gtShapeTableFor:
]

{ #category : 'accessing' }
GcLayer >> index [
	^ index
]

{ #category : 'testing' }
GcLayer >> isBand [
	"A band is a non-layer row (embeddings or head/final), which has no numeric layer index."
	^ index isNil
]

{ #category : 'accessing' }
GcLayer >> label [
	"A short row label: L<n> for a transformer layer, or a named band for the non-layer tensors."
	index ifNotNil: [ ^ 'L' , index printString ].
	(tensors items anySatisfy: [ :t | t parsedName block = #embedding ])
		ifTrue: [ ^ '(embeddings)' ].
	^ '(head / final)'
]

{ #category : 'accessing' }
GcLayer >> modelGroup [
	^ modelGroup
]

{ #category : 'printing' }
GcLayer >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(.
	aStream nextPutAll: self label.
	aStream nextPutAll: ', '.
	aStream print: tensors size.
	aStream nextPutAll: ' tensors)'
]

{ #category : 'regularity' }
GcLayer >> regularityScores [
	"This layer's tensors' regularity scores, drawn from the whole-model cohort statistics."
	| all |
	all := modelGroup regularityScores.
	^ tensors items collect: [ :t | all at: t ]
]

{ #category : 'initialization' }
GcLayer >> setIndex: anIndexOrNil tensors: aTensorCollection modelGroup: aTensorGroup [
	index := anIndexOrNil.
	tensors := (aTensorCollection isKindOf: GcTensorGroup)
		ifTrue: [ aTensorCollection ]
		ifFalse: [ GcTensorGroup withAll: aTensorCollection asOrderedCollection ].
	modelGroup := aTensorGroup
]

{ #category : 'accessing' }
GcLayer >> tensors [
	^ tensors
]

{ #category : 'accessing' }
GcLayer >> totalParams [
	^ tensors totalParams
]
