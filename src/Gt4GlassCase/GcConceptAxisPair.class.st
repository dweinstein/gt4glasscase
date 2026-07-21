"
Stage C relationship between two GcConceptAxes within one GcConceptAxisSpace: the ordered pair (first, second) plus the ANGLE in degrees between their directions. Materializes an angle-matrix cell click as a MOLDABLE domain object (with views onto both axes and the angle) so the click lands here, not on a raw two-element Array. Mirrors GcConceptPair. The angle is resolved lazily against the owning space's model.
"
Class {
	#name : 'GcConceptAxisPair',
	#superclass : 'Object',
	#instVars : [
		'first',
		'second',
		'space'
	],
	#category : 'Gt4GlassCase-Embedding',
	#package : 'Gt4GlassCase',
	#tag : 'Embedding'
}

{ #category : 'instance creation' }
GcConceptAxisPair class >> first: anAxis second: anotherAxis in: aSpace [
	^ self new setFirst: anAxis second: anotherAxis space: aSpace
]

{ #category : 'accessing' }
GcConceptAxisPair >> angle [
	"Angle in degrees between my two axis directions within my space's model."
	^ space angleBetween: first and: second
]

{ #category : 'accessing' }
GcConceptAxisPair >> first [
	^ first
]

{ #category : 'gt views' }
GcConceptAxisPair >> gtAxesFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Axes';
		priority: 10;
		items: [ { first. second } ];
		column: 'Axis' text: [ :ax | ax name ];
		column: 'Negative (-)' text: [ :ax | ax negativeLabel ];
		column: 'Positive (+)' text: [ :ax | ax positiveLabel ];
		send: [ :ax | ax ]
]

{ #category : 'gt views' }
GcConceptAxisPair >> gtDetailsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Details';
		priority: 20;
		items: [ {
			'first' -> (first ifNil: [ '?' ] ifNotNil: [ :a | a name ]).
			'second' -> (second ifNil: [ '?' ] ifNotNil: [ :a | a name ]).
			'angle (deg)' -> (self angle printShowingDecimalPlaces: 3).
			'relation' -> self relationLabel } ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ]
]

{ #category : 'printing' }
GcConceptAxisPair >> printOn: aStream [
	aStream nextPutAll: (first ifNil: [ '?' ] ifNotNil: [ :a | a name ]).
	aStream nextPutAll: ' / '.
	aStream nextPutAll: (second ifNil: [ '?' ] ifNotNil: [ :a | a name ]).
	(space notNil and: [ first notNil and: [ second notNil ] ]) ifTrue: [
		aStream nextPutAll: ' ('; nextPutAll: (self angle printShowingDecimalPlaces: 1); nextPutAll: ' deg)' ]
]

{ #category : 'accessing' }
GcConceptAxisPair >> relationLabel [
	| a |
	a := self angle.
	^ (a - 90.0) abs < 15.0
		ifTrue: [ 'independent (~90 deg)' ]
		ifFalse: [ (a < 60.0 or: [ a > 120.0 ]) ifTrue: [ 'entangled' ] ifFalse: [ 'partly related' ] ]
]

{ #category : 'accessing' }
GcConceptAxisPair >> second [
	^ second
]

{ #category : 'initialization' }
GcConceptAxisPair >> setFirst: anAxis second: anotherAxis space: aSpace [
	first := anAxis.
	second := anotherAxis.
	space := aSpace
]

{ #category : 'accessing' }
GcConceptAxisPair >> space [
	^ space
]
